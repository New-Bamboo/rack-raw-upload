# WARNING: you may not need this

If you want to use this because you are performing HTML5 file uploads, you may be doing it [the "old way"](http://blog.new-bamboo.co.uk/2010/7/30/html5-powered-ajax-file-uploads).

There is a "new", [better way of doing this](http://blog.new-bamboo.co.uk/2012/01/10/ridiculously-simple-ajax-uploads-with-formdata). It may be a better solution for your problems.

However, if this is not the case, please read on. I hope you find this middleware useful.

# Rack Raw Upload middleware

Rack::RawUpload converts raw uploads into normal multipart requests, like those in a form. Rack applications can then read these as normal (using `params` for example), rather than from `env['rack.input']` or similar.

## Assumptions

Rack::RawUpload performs this conversion when all these conditions are met:

1. The request method is POST or PUT
2. The mimetype is one of
    * `application/x-www-form-urlencoded`
    * `multipart/form-data`
3. The Content-Length is greater than 0

## Configuration

### Bog-standard Rack app

The simpler case. Add these lines in your `config.ru`, where appropriate:

    require 'rack/raw_upload'
    use Rack::RawUpload

If you want to limit the conversion to a few known paths, do:

    require 'rack/raw_upload'
    use Rack::RawUpload, :paths => ['/upload/path', '/alternative/path.*']

You can also make it so that the conversion only happens when explicitly required by the client using a header. This would be `X-File-Upload: true` to make the conversion regardless of the content type. A value of `X-File-Upload: smart` would ask for the normal detection to be performed. For this, use the following setting:

    use Rack::RawUpload, :explicit => true

### Ruby on Rails

Add this to your Gemfile

    gem 'rack-raw-upload'

and then add the middleware in application.rb

    config.middleware.use 'Rack::RawUpload'


## Usage

The upload is made into a request argument called `file`. In several popular frameworks, this can be accessed as `params[:file]`. This includes Rails and Sinatra, but may be different in other frameworks.


## Optional request headers

Raw uploads, due to their own nature, can't provide additional arguments in the request. This limitation can be worked around using headers.

* `X-File-Name`: specify the name of the uploaded file.
* `X-File-Upload`: explicitly tells whether to perform the conversion or not. Possible values are 'true' (string), 'false' (string) or 'smart'. Default is 'smart', unless the middleware is initialized with `:explicit => true`, in which case default is 'false'.
* `X-Params`: query string with additional arguments. On Rails or Sinatra, you can read these as `params[:name_of_argument]`.
* `X-JSON-Params`: same thing, but in the form of a JSON string.
* `X-Query-Params`: **deprecated**. Equivalent to `X-JSON-Params`. Will be removed in future versions.


## Additional info

A blog post on Ajax uploads. These are raw uploads and can be greatly simplified with this middleware:

* [http://blog.new-bamboo.co.uk/2010/7/30/html5-powered-ajax-file-uploads](http://blog.new-bamboo.co.uk/2010/7/30/html5-powered-ajax-file-uploads)

This middleware should work with Ruby 1.8.7, 1.9.2, 1.9.3, REE, Rubinius and JRuby. Tests for all these platforms are run on the wonderful [Travis-CI](http://travis-ci.org/) regularly, and the current status of these is: [![Build Status](http://travis-ci.org/newbamboo/rack-raw-upload.png)](http://travis-ci.org/newbamboo/rack-raw-upload)
