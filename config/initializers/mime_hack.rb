class Mime::Type
  delegate :split, :to => :to_s
end
