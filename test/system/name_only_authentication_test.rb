require "application_system_test_case"

class NameOnlyAuthenticationSystemTest < ApplicationSystemTestCase
  setup do
    FastRetro.stubs(:name_only?).returns(true)
    FastRetro.stubs(:saas?).returns(false)
  end

  test "a facilitator creates a team and restores it using the saved token" do
    visit new_signup_path(script_name: nil)
    fill_in "Your name", with: "Browser Facilitator"
    click_on "Create team"

    assert_selector "h1", text: /save your recovery token/i
    token = find("#recovery_token").value
    assert_match(/\Afr_[a-zA-Z0-9]{43}\z/, token)
    identity = Identity.find_by_recovery_token(token)
    user = identity.users.sole

    click_on "Continue"
    assert_current_path retros_path(script_name: user.account.slug)
    visit user_path(user, script_name: user.account.slug)
    assert_text(/browser facilitator/i)
    assert_no_selector "a[href^='mailto:']"
    click_on "Sign Out"
    assert_selector "input[name='recovery_token']"
    fill_in "Recovery token", with: token
    click_on "Restore access"
    assert_current_path retros_path(script_name: user.account.slug)
    visit user_path(user, script_name: user.account.slug)
    assert_text(/browser facilitator/i)
  end

  test "an invited participant enters only a name and is remembered on later visits" do
    code = account_join_codes(:one)
    retro = retros(:one)
    invite = retro_invite_path(code: code.code, retro_id: retro.id, script_name: nil)
    visit invite
    assert_no_selector "input[type='email']"
    fill_in "Your name", with: "Browser Participant"
    click_on "Join"
    assert_no_selector "input[name='full_name']"

    user = User.find_by!(name: "Browser Participant")
    assert retro.participant?(user)
    assert_not retro.admin?(user)
    visit invite
    assert_no_selector "input[name='full_name']"
    assert_equal 1, User.where(name: "Browser Participant").count
    visit user_path(user, script_name: user.account.slug)
    click_on "Recovery token"
    click_on "Generate replacement token"
    assert_selector "#recovery_token"
  end
end
