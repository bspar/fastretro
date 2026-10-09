require "test_helper"

class NameOnlyAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    FastRetro.stubs(:name_only?).returns(true)
    FastRetro.stubs(:saas?).returns(false)
  end

  test "signup asks only for a name and creates a remembered verified owner without mail" do
    untenanted do
      get new_signup_path
      assert_select "input[name='signup[full_name]']"
      assert_select "input[type=email]", count: 0

      assert_no_enqueued_jobs do
        assert_difference [ "Identity.count", "Account.count", "User.count", "Session.count" ], 1 do
          post signup_path, params: { signup: { full_name: "  Facilitator  ", email_address: identities(:one).email_address, role: "staff" } }
        end
      end
      identity = signed_in_identity
      assert identity.name_only?
      assert_not identity.staff?
      owner = identity.users.sole
      assert_equal "Facilitator", owner.name
      assert owner.owner?
      assert owner.verified?
      assert_redirected_to my_recovery_token_path

      follow_redirect!
      assert_response :success
      token = response.parsed_body.at_css("#recovery_token")["value"]
      assert_equal identity, Identity.find_by_recovery_token(token)
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.body, 'name="turbo-cache-control" content="no-cache"'

      get my_recovery_token_path
      assert_select "#recovery_token", count: 0
      get root_path
      assert_redirected_to session_menu_path
      assert_equal identity, signed_in_identity
    end
  end

  test "blank and oversized names do not create identities or accounts" do
    untenanted do
      [ " ", "x" * 101 ].each do |name|
        assert_no_difference [ "Identity.count", "Account.count", "Session.count" ] do
          post signup_path, params: { signup: { full_name: name } }
        end
        assert_response :unprocessable_entity
      end
    end
  end

  test "recovery authenticates the original identity without creating another team" do
    identity = Identity.create_name_only!
    token = identity.reset_recovery_token
    identity.join(accounts(:one), name: "Facilitator", role: :admin)

    untenanted do
      assert_no_difference [ "Identity.count", "Account.count", "User.count" ] do
        assert_no_enqueued_jobs do
          post session_path, params: { recovery_token: " #{token} " }
        end
      end
      assert_redirected_to session_menu_path
      assert_equal identity, signed_in_identity
      assert identity.users.sole.admin?
      assert_not_includes response.body, token
    end
  end

  test "invalid recovery does not create a session or fall back to email or name lookup" do
    untenanted do
      assert_no_enqueued_jobs do
        assert_no_difference "Session.count" do
          post session_path, params: { recovery_token: users(:one).name, email_address: identities(:one).email_address }
        end
      end
      assert_response :unprocessable_entity
      assert_not_predicate cookies[:session_token], :present?
      assert_select "input[type=email]", count: 0
    end
  end

  test "recovery-token replacement revokes the old token and other sessions only" do
    untenanted do
      post signup_path, params: { signup: { full_name: "Facilitator" } }
      identity = signed_in_identity
      old_token = session[:name_only_recovery_token]
      own_session = identity.sessions.sole
      other_session = identity.sessions.create!
      unrelated_session = identities(:one).sessions.create!

      post my_recovery_token_path, params: { identity_id: identities(:one).id }
      assert_redirected_to my_recovery_token_path
      replacement = session[:name_only_recovery_token]
      assert_nil Identity.find_by_recovery_token(old_token)
      assert_equal identity, Identity.find_by_recovery_token(replacement)
      assert Session.exists?(own_session.id)
      assert_not Session.exists?(other_session.id)
      assert Session.exists?(unrelated_session.id)

      delete session_path
      assert_nil session[:name_only_recovery_token]
      assert_not_predicate cookies[:session_token], :present?
      post session_path, params: { recovery_token: old_token }
      assert_response :unprocessable_entity
      post session_path, params: { recovery_token: replacement }
      assert_redirected_to session_menu_path
    end
  end

  test "the recovery-token page requires authentication and is disabled outside name-only mode" do
    untenanted do
      get my_recovery_token_path
      assert_response :redirect
      post signup_path, params: { signup: { full_name: "Facilitator" } }
      FastRetro.stubs(:name_only?).returns(false)
      get my_recovery_token_path
      assert_response :not_found
    end
  end

  test "retro invitation joins immediately by name with participant permissions and no email" do
    code = account_join_codes(:one)
    retro = retros(:one)
    url = retro_invite_path(code: code.code, retro_id: retro.id, script_name: nil)

    get url
    assert_select "input[name=full_name]"
    assert_select "input[type=email]", count: 0
    assert_no_enqueued_jobs do
      assert_difference [ "Identity.count", "User.count", "Session.count" ], 1 do
        post url, params: { full_name: users(:one).name, role: "admin", identity_id: identities(:one).id }
      end
    end
    identity = signed_in_identity
    user = identity.users.sole
    assert identity.name_only?
    assert_not_equal identities(:one), identity
    assert user.member?
    assert user.verified?
    assert retro.participant?(user)
    assert_not retro.admin?(user)
    assert_nil identity.recovery_token_digest
    assert_redirected_to retro_path(retro, script_name: accounts(:one).slug)

    assert_no_difference [ "Identity.count", "User.count", "Session.count" ] do
      get url
    end
    assert_equal identity, signed_in_identity
  end

  test "a second browser with the same name creates a different participant not an impersonation" do
    code = account_join_codes(:one)
    retro = retros(:one)
    url = retro_invite_path(code: code.code, retro_id: retro.id, script_name: nil)
    post url, params: { full_name: "Same Name" }
    first = signed_in_identity
    other_browser = open_session
    other_browser.post url, params: { full_name: "Same Name" }
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(other_browser.request, other_browser.cookies.to_hash)
    second = Session.find_signed!(cookie_jar.signed[:session_token]).identity

    assert_not_equal first, second
    assert_equal first.users.sole.name, second.users.sole.name
    assert second.users.sole.member?
  end

  test "team invites support names and reject blank names without consuming the invite" do
    account = accounts(:one)
    code = account_join_codes(:one)
    get join_path(code.code)
    assert_select "input[name=full_name]"
    assert_no_difference [ "Identity.count", "User.count", -> { code.reload.usage_count } ] do
      post join_path(code.code), params: { full_name: " " }
    end
    assert_response :unprocessable_entity

    assert_no_enqueued_jobs do
      post join_path(code.code), params: { full_name: "Team Member" }
    end
    assert_redirected_to landing_path(script_name: account.slug)
    assert_equal "Team Member", signed_in_identity.users.sole.name
  end

  test "invalid expired and cross-account retro invites do not create identities" do
    code = account_join_codes(:one)
    assert_no_difference [ "Identity.count", "Session.count", "User.count" ] do
      post retro_invite_path(code: "invalid", retro_id: retros(:one).id, script_name: nil), params: { full_name: "Guest" }
      assert_response :redirect
      post retro_invite_path(code: code.code, retro_id: retros(:other_account_retro).id, script_name: nil), params: { full_name: "Guest" }
      assert_response :redirect
      code.update!(usage_count: code.usage_limit)
      post retro_invite_path(code: code.code, retro_id: retros(:one).id, script_name: nil), params: { full_name: "Guest" }
      assert_response :redirect
    end
  end

  test "restoring from an invite returns to the same retro" do
    identity = Identity.create_name_only!
    identity.join(accounts(:two), name: "Returning Member")
    token = identity.reset_recovery_token
    code = account_join_codes(:one)
    retro = retros(:one)
    url = retro_invite_path(code: code.code, retro_id: retro.id, script_name: nil)

    get url
    untenanted do
      post session_path, params: { recovery_token: token }
      assert_redirected_to url
    end
    follow_redirect!
    assert_redirected_to retro_path(retro, script_name: accounts(:one).slug)
    assert_equal "Returning Member", identity.users.find_by!(account: accounts(:one)).name
  end

  test "name-only profile hides email and provides an optional recovery token" do
    code = account_join_codes(:one)
    post join_path(code.code), params: { full_name: "Participant" }
    user = signed_in_identity.users.sole

    get user_path(user)
    assert_select "a[href='#{my_recovery_token_path(script_name: nil)}']", text: "Recovery token"
    assert_not_includes response.body, user.identity.email_address
    get edit_user_path(user)
    assert_select "input[type=email]", count: 0
    get new_user_email_address_path(user)
    assert_response :not_found

    untenanted do
      post my_recovery_token_path
      follow_redirect!
      assert_select "#recovery_token"
    end
  end

  test "name-only signup is not used when disabled" do
    FastRetro.stubs(:name_only?).returns(false)
    untenanted do
      get new_signup_path
      assert_select "input[type=email]"
      assert_select "input[name='signup[full_name]']", count: 0
    end
  end

  test "an internal placeholder address cannot request email login when name-only mode is disabled" do
    identity = Identity.create_name_only!
    FastRetro.stubs(:name_only?).returns(false)
    untenanted do
      assert_no_enqueued_jobs do
        assert_no_difference [ "Session.count", "MagicLink.count" ] do
          post session_path, params: { email_address: identity.email_address }
        end
      end
      assert_redirected_to session_magic_link_path
      assert_not_predicate cookies[:session_token], :present?
    end
  end

  private
    def signed_in_identity
      Session.find_signed!(parsed_cookies.signed[:session_token]).identity
    end
end
