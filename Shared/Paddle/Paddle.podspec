Pod::Spec.new do |s|
  s.name        = "Paddle"
  s.version     = "2.3.7"
  s.summary     = "A licensing framework for OS X"
  s.description = "Paddle is an easy to use licensing framework for OS X including App Licensing and In App Purchases."
  s.homepage    = "https://www.paddle.com"
  s.license     = {
    :type => 'MIT',
    :file => 'LICENSE'
  }
  s.authors     = {
    'Louis Harwood' => 'louis@paddle.com',
    'Christian Owens' => 'christian@paddle.com',
  }

  s.platform = :osx, '10.7'
  s.source   = { :http => "https://github.com/PaddleHQ/Mac-Framework/archive/v2.3.7.tar.gz" }

  s.vendored_framework  = 'Paddle.framework'
  s.requires_arc        = false
  s.framework           = 'WebKit';
end
