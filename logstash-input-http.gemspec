Gem::Specification.new do |s|
  s.name = 'logstash-input-http'
  s.version         = '0.1.1'
  s.licenses = ['Apache License (2.0)']
  s.summary = "This is alpha version of tail http input."
  s.description = "Tail log file from http url"
  s.authors = ["StarshayaYord"]
  s.email = 'starshayayord@gmail.com'
  s.homepage = "https://github.com/starshayayord/logstash-input-http"
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", '>= 1.4.0', '< 2.0.0'
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'stud'
  s.add_development_dependency 'logstash-devutils'
end
