# Haml 5.2 compatibility: quirks_mode was removed but old templates and haml-rails still pass it
# Patch to filter it out from options hashes, handling Temple::ImmutableMap

def filter_quirks_mode(options)
  return options unless options.is_a?(Hash) || (defined?(Temple::ImmutableMap) && options.is_a?(Temple::ImmutableMap))
  # Convert ImmutableMap to hash
  h = options.is_a?(Hash) ? options.dup : options.to_h
  h.delete(:quirks_mode)
  h.delete("quirks_mode")
  h.delete(:ugly)
  h.delete("ugly")
  h
end

# Patch Haml::Engine
if defined?(Haml::Engine)
  Haml::Engine.class_eval do
    alias_method :orig_engine_init, :initialize
    def initialize(template, options = {})
      if defined?(Temple::ImmutableMap) && options.is_a?(Temple::ImmutableMap)
        options = options.to_h
      end
      if options.is_a?(Hash)
        options = options.dup
        options.delete(:quirks_mode)
        options.delete("quirks_mode")
        options.delete(:ugly)
        options.delete("ugly")
      end
      orig_engine_init(template, options)
    end
  end
end

# Patch Tilt::HamlTemplate
if defined?(Tilt::HamlTemplate)
  Tilt::HamlTemplate.class_eval do
    alias_method :orig_tilt_init, :initialize
    def initialize(file=nil, line=1, options={}, &block)
      if defined?(Temple::ImmutableMap) && options.is_a?(Temple::ImmutableMap)
        options = options.to_h
      end
      if options.is_a?(Hash)
        options = options.dup
        options.delete(:quirks_mode)
        options.delete("quirks_mode")
        options.delete(:ugly)
      end
      orig_tilt_init(file, line, options, &block)
    end
  end
end

# Patch Haml::Parser
if defined?(Haml::Parser)
  Haml::Parser.class_eval do
    alias_method :orig_parser_init, :initialize
    def initialize(options={})
      if defined?(Temple::ImmutableMap) && options.is_a?(Temple::ImmutableMap)
        options = options.to_h
      end
      if options.is_a?(Hash)
        options = options.dup
        options.delete(:quirks_mode)
        options.delete("quirks_mode")
      end
      orig_parser_init(options)
    end
  end
end

# Patch Haml::Compiler
if defined?(Haml::Compiler)
  Haml::Compiler.class_eval do
    alias_method :orig_compiler_init, :initialize
    def initialize(options={})
      if defined?(Temple::ImmutableMap) && options.is_a?(Temple::ImmutableMap)
        options = options.to_h
      end
      if options.is_a?(Hash)
        options = options.dup
        options.delete(:quirks_mode)
        options.delete("quirks_mode")
      end
      orig_compiler_init(options)
    end
  end
end

# Patch Javascript filter
if defined?(Haml::Filters::Javascript)
  Haml::Filters::Javascript.class_eval do
    alias_method :orig_js_render, :render_with_options rescue nil
    def render_with_options(text, options={})
      if defined?(Temple::ImmutableMap) && options.is_a?(Temple::ImmutableMap)
        options = options.to_h
      end
      if options.is_a?(Hash)
        options = options.dup
        options.delete(:quirks_mode)
        options.delete("quirks_mode")
      end
      if defined?(orig_js_render)
        orig_js_render(text, options)
      else
        super(text, options)
      end
    end
  end
end

# Remove quirks_mode from global Haml options
begin
  if defined?(Haml::Template) && Haml::Template.respond_to?(:options) && Haml::Template.options.is_a?(Hash)
    Haml::Template.options.delete(:quirks_mode)
    Haml::Template.options.delete("quirks_mode")
  end
rescue
end
begin
  if defined?(Haml::Options) && Haml::Options.respond_to?(:defaults) && Haml::Options.defaults.is_a?(Hash)
    Haml::Options.defaults.delete(:quirks_mode)
  end
rescue
end

# Ensure XML serialization is available
require "active_model/serializers/xml" rescue nil
require "rexml/document" rescue nil
require "active_support/core_ext/hash/conversions" rescue nil

# Patch ActiveModel::Errors to support to_xml
unless ActiveModel::Errors.method_defined?(:to_xml)
  class ActiveModel::Errors
    def to_xml(options = {})
      options[:root] ||= "errors"
      xml = +"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      xml << "<#{options[:root]} type=\"array\">\n"
      full_messages.each do |msg|
        xml << "  <error>#{ERB::Util.html_escape(msg)}</error>\n"
      end
      xml << "</#{options[:root]}>\n"
      xml
    end
  end
end

if defined?(ActiveModel::Error) && !ActiveModel::Error.method_defined?(:to_xml)
  class ActiveModel::Error
    def to_xml(options = {})
      "<error>#{ERB::Util.html_escape(full_message)}</error>"
    end
  end
end
