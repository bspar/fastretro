require "test_helper"

class Identity::NameOnlyAuthenticatableTest < ActiveSupport::TestCase
  test "name-only mode requires an explicit opt-in and self-hosted mode" do
    with_env("NAME_ONLY_AUTH" => "true") do
      FastRetro.stubs(:saas?).returns(false)
      assert FastRetro.name_only?
      FastRetro.stubs(:saas?).returns(true)
      assert_not FastRetro.name_only?
    end
    with_env("NAME_ONLY_AUTH" => nil) do
      assert_not FastRetro.name_only?
    end
  end

  test "each new identity has a unique non-deliverable internal address" do
    first = Identity.create_name_only!
    second = Identity.create_name_only!

    assert first.name_only?
    assert first.email_address.end_with?("@name-only.invalid")
    assert_not_equal first.email_address, second.email_address
    assert_nil first.recovery_token_digest
  end

  test "recovery stores a digest and rotation invalidates the old token" do
    identity = Identity.create_name_only!
    token = identity.reset_recovery_token

    assert_match(/\Afr_[a-zA-Z0-9]{43}\z/, token)
    assert_equal identity, Identity.find_by_recovery_token(token)
    assert_equal Digest::SHA256.hexdigest(token), identity.reload.recovery_token_digest
    assert_not_includes identity.attributes.values, token

    replacement = identity.reset_recovery_token
    assert_nil Identity.find_by_recovery_token(token)
    assert_equal identity, Identity.find_by_recovery_token(replacement)
    assert_nil Identity.find_by_recovery_token("")
    assert_nil Identity.find_by_recovery_token("fr_#{'a' * 43}")
    assert_nil Identity.find_by_recovery_token("a" * 10_000)
  end

  test "email identities cannot issue or use recovery tokens" do
    identity = identities(:one)
    assert_raises(ArgumentError) { identity.reset_recovery_token }
    token = "fr_#{SecureRandom.base58(43)}"
    identity.update!(recovery_token_digest: Digest::SHA256.hexdigest(token))
    assert_nil Identity.find_by_recovery_token(token)
  end

  test "name-only identities never send magic links even after mode is disabled" do
    assert_no_enqueued_jobs do
      assert_raises(ArgumentError) { Identity.create_name_only!.send_magic_link }
    end
  end

  test "an exhausted invite rolls back the newly created identity" do
    code = account_join_codes(:one)
    code.update!(usage_count: code.usage_limit)
    signup = Signup.new(full_name: "Participant")

    assert_no_difference [ "Identity.count", "User.count" ] do
      assert_not signup.join_by_name(code)
    end
  end
end
