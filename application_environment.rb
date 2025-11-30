class ApplicationEnvironment
  def self.development?
    ENV['ENVIRONMENT'] == 'development'
  end

  def self.production?
    ENV['ENVIRONMENT'] == 'production'
  end

  def self.test?
    ENV['ENVIRONMENT'] == 'test'
  end
end
