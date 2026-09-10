module ApplicationHelper
  def visible?(flag)
    flag ? nil : "display: none"
  end

  def application_revision
    @application_revision ||= if File.exist?(Rails.root.join("REVISION"))
      File.read(Rails.root.join("REVISION")).strip
    else
      "HEAD"
    end
  end

  def application_last_deployed
    if File.exist?(Rails.root.join("REVISION"))
      @deployed_at ||= File.stat(Rails.root.join("REVISION")).ctime
      time_ago_in_words(@deployed_at) + " ago"
    else
      "(not deployed)"
    end
  end

  def format_cents(amount, options={})
    number_to_currency(amount.to_f / 100.0, options)
  end
end
