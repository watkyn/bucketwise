require "test_helper"

class ImportmapTest < ActiveSupport::TestCase
  test "importmap pins money for controllers that import it" do
    imports = self.imports

    assert imports.key?("money"),
           "importmap must pin \"money\" (app/javascript/money.js); got keys: #{imports.keys.inspect}"
    refute imports.key?("javascript/money"),
           "stale javascript/money pin should not be present"
  end

  test "every bare import in app/javascript resolves in the importmap" do
    imports = self.imports
    missing = []

    Dir[Rails.root.join("app/javascript/**/*.js")].sort.each do |file|
      source = File.read(file)
      bare_imports(source).each do |specifier|
        next if imports.key?(specifier)
        missing << "#{file.delete_prefix(Rails.root.to_s + "/")}: imports #{specifier.inspect} (not in importmap)"
      end
    end

    assert_empty missing, "Unpinned imports prevent modules from loading:\n#{missing.join("\n")}"
  end

  test "every importmap asset path resolves to a real file" do
    imports = self.imports
    unresolved = []

    imports.each do |name, path|
      logical = path.sub(%r{\A/assets/}, "").sub(/-[0-9a-f]{8,}(\.\w+)\z/, '\1')
      resolved = Rails.application.assets.resolver.resolve(logical)
      unresolved << "#{name} => #{path} (resolve(#{logical.inspect}) => #{resolved.inspect})" if resolved.nil?
    end

    assert_empty unresolved, "Importmap entries with unresolvable assets:\n#{unresolved.join("\n")}"
  end

  test "money.js source is exported for named import" do
    resolved = Rails.application.assets.resolver.resolve("money.js")
    assert resolved, "money.js not found on asset load path"

    source = File.read(Rails.root.join("app/javascript/money.js"))
    assert_match(/export\s+(?:const|function|\{)/, source,
                 "money.js must export Money for `import { Money } from \"money\"`")
  end

  private

  def rendered_importmap
    html = ApplicationController.renderer.render(template: "layouts/application", assigns: {})
    match = html.match(%r{<script type="importmap"[^>]*>(.*?)</script>}m)
    assert match, "layout did not render an importmap script tag"

    JSON.parse(match[1])
  end

  def imports
    rendered_importmap.fetch("imports")
  end

  def bare_imports(source)
    source.scan(/\bfrom\s+["']([^"']+)["']/).flatten.uniq.reject do |spec|
      spec.start_with?(".", "/", "@hotwired/")
    end
  end
end
