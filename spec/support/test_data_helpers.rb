module TestDataHelpers
  def unique_email(prefix = "user")
    "#{prefix}-#{SecureRandom.hex(4)}@example.com"
  end
end
