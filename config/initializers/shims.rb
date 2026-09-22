# Shim for BucketWise version loading
begin
  require Rails.root.join("lib/bucket_wise/version")
rescue LoadError
  require "bucket_wise/version" rescue nil
end

# Shim for ActiveModel::Errors#each_full (used by account form error display)
class ActiveModel::Errors
  unless method_defined?(:each_full)
    def each_full(&block)
      full_messages.each(&block)
    end
  end
end
