module OptionHandler
  private

    # For appending info to serialization options hash, where attributes
    # may be arrays, hashes, or singleton values.
    def append_to_options(options, attribute, extras)
      case options[attribute]
      when Array
        case extras
        when Array
          options[attribute].concat(extras)
        when Hash
          old, options[attribute] = options[attribute], extras
          old.each { |key| options[attribute][key] ||= {} }
        else
          options[attribute] << extras
        end

      when Hash
        case extras
        when Array
          extras.each { |key| options[attribute][key] ||= {} }
        when Hash
          extras.each { |key, value| options[attribute][key] ||= value }
        else
          options[attribute][extras] ||= {}
        end

      else
        options[attribute] = extras
      end
    end
end
