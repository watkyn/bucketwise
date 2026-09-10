# Fixes for json 3.0.2 + Ruby 3.4 incompatibility with the legacy quirks_mode option.
# ActiveSupport (and this legacy app) pass quirks_mode: true to JSON.parse/JSON.generate,
# which the json C extension no longer accepts as a keyword argument.

# --- Patch JSON.generate / JSON.parse to strip legacy quirks_mode ---
module JSON
  class << self
    alias_method :orig_generate, :generate
    def generate(obj, opts = nil, **kwargs)
      opts = merge_legacy_opts(opts, kwargs)
      opts = strip_legacy_opts(opts)
      orig_generate(obj, opts)
    end

    alias_method :orig_parse, :parse
    def parse(source, opts = nil, **kwargs)
      opts = merge_legacy_opts(opts, kwargs)
      opts = strip_legacy_opts(opts)
      orig_parse(source, **opts)
    end

    private

    def merge_legacy_opts(opts, kwargs)
      if opts.is_a?(Hash)
        kwargs.any? ? opts.merge(kwargs) : opts
      elsif kwargs.any?
        kwargs
      else
        opts
      end
    end

    def strip_legacy_opts(opts)
      return opts unless opts.is_a?(Hash)
      opts = opts.dup
      opts.delete(:quirks_mode)
      opts.delete("quirks_mode")
      opts.delete(:max_nesting) if opts[:max_nesting] == false
      opts.delete("max_nesting") if opts["max_nesting"] == false
      opts
    end
  end
end

module JSON
  module Ext
    module Generator
      class State
        class << self
          alias_method :orig_state_generate, :generate rescue nil
          def generate(obj, opts = nil, io = nil)
            if opts.is_a?(Hash)
              opts = opts.dup
              opts.delete(:quirks_mode)
              opts.delete("quirks_mode")
            end
            orig_state_generate(obj, opts, io)
          rescue ArgumentError => e
            if e.message.include?("quirks_mode")
              opts = opts.dup if opts.is_a?(Hash)
              opts.delete(:quirks_mode) if opts.is_a?(Hash)
              orig_state_generate(obj, opts, io)
            else
              raise
            end
          end
        end
      end
    end
  end
end

# --- Patch ActiveSupport::JSON.decode, which calls JSON.parse(json, quirks_mode: true) ---
# Used when deserializing encrypted session cookies.
module ActiveSupport
  module JSON
    class << self
      alias_method :decode_without_legacy_patch, :decode rescue nil

      def decode(json)
        data = ::JSON.parse(json)
        if ActiveSupport.parse_json_times
          convert_dates_from(data)
        else
          data
        end
      end
      alias_method :load, :decode
    end
  end
end