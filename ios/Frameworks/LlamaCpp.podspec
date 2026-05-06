Pod::Spec.new do |s|
  s.name             = 'LlamaCpp'
  s.version          = '0.9.0-dev.6'
  s.summary          = 'llama.cpp xcframework vendored for llama_cpp_dart'
  s.homepage         = 'https://github.com/netdur/llama_cpp_dart'
  s.license          = { :type => 'MIT' }
  s.author           = { 'netdur' => 'noreply@netdur.dev' }
  s.source           = { :http => 'https://github.com/netdur/llama_cpp_dart' }
  s.platform         = :ios, '14.0'
  s.vendored_frameworks = 'llama.xcframework'
  s.static_framework = true
  s.frameworks = 'Accelerate'
end
