# Shim for BucketWise version loading
begin
  require Rails.root.join("lib/bucket_wise/version")
rescue LoadError
  require "bucket_wise/version" rescue nil
end

# Patch form_for to handle legacy 3-arg: form_for(:account, @account, url: ...)
module ActionView
  module Helpers
    module FormHelper
      alias_method :form_for_without_legacy, :form_for rescue nil
      def form_for(*args, &block)
        if args.length == 3 && args[0].is_a?(Symbol) && (args[1].is_a?(ActiveRecord::Base) || args[1].nil?) && args[2].is_a?(Hash)
          record = args[1] || (args[0].to_s.classify.constantize.new rescue nil)
          options = args[2]
          return form_for_without_legacy(record, options, &block) if respond_to?(:form_for_without_legacy)
          return super(record, options, &block)
        elsif args.length == 2 && args[0].is_a?(Symbol) && (args[1].is_a?(ActiveRecord::Base) || args[1].nil?)
          record = args[1] || (args[0].to_s.classify.constantize.new rescue nil)
          return form_for_without_legacy(record, &block) if respond_to?(:form_for_without_legacy)
          return super(record, &block)
        end
        if respond_to?(:form_for_without_legacy)
          form_for_without_legacy(*args, &block)
        else
          super(*args, &block)
        end
      end
    end
  end
end

# Also patch Haml's form_for wrapper if present
if defined?(Haml::Helpers::ActionViewMods::FormHelper) || defined?(ActionView::Helpers::FormHelper)
  module Haml
    module Helpers
      module ActionViewMods
        if const_defined?(:FormHelper)
          FormHelper.class_eval do
            alias_method :orig_haml_form_for, :form_for_with_haml_xss rescue nil
            def form_for_with_haml_xss(*args, &block)
              if args.length == 3 && args[0].is_a?(Symbol) && args[1].is_a?(ActiveRecord::Base) && args[2].is_a?(Hash)
                args = [args[1], args[2]]
              elsif args.length == 2 && args[0].is_a?(Symbol) && args[1].is_a?(ActiveRecord::Base)
                args = [args[1]]
              end
              if defined?(orig_haml_form_for)
                orig_haml_form_for(*args, &block)
              else
                super(*args, &block)
              end
            end
          end
        end
      end
    end
  end
end

# Shim for h() alias (html_escape)
module HHelperShim
  def h(text)
    ERB::Util.html_escape(text)
  end
end
ActionView::Base.include(HHelperShim) if !ActionView::Base.method_defined?(:h)

# Shim for ActiveModel::Errors#each_full (old API)
class ActiveModel::Errors
  unless method_defined?(:each_full)
    def each_full(&block)
      full_messages.each(&block)
    end
  end
end
