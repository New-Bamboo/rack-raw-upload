# Rack Raw Upload middleware

Rack::RawUpload converts raw file uploads into normal form input, so Rack applications can read these as normal (using `params` for example), rather than from `env['rack.input']` or similar.

Rack::RawUpload know that a request is such an upload when the mimetype **is not** one of the following:

* application/x-www-form-urlencoded
* multipart/form-data

Additionally, it can be told explicitly to perform the conversion, using the header `X-File-Upload`. See below for details.

## Assumptions

Rack::RawUpload expects that requests will:

1. be POST or PUT requests
2. set the mimetype `application/octet-stream`


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

## More options

### Specifying the file name of the upload

Raw uploads, due to their own nature, don't include the name of the file being uploaded. You can work around this limitation by specifying the filename as an HTTP header.

When present, Rack::RawUpload will assume that the header ***`X-File-Name`*** will contain the filename.

### Additional query parameters

Again, the nature of raw uploads prevents us from sending additional parameters along with the file. As a workaround, you can specify there as a header too. They will be made available as normal parameters.

When present, Rack::RawUpload will assume that the header ***`X-Query-Params`*** contains these additional parameters. The values are expected to be in the form of a **JSON** hash.

## Additional info

A blog post on HTML5 uploads, which are raw uploads, and can be greatly simplified with this middleware:

* [http://blog.new-bamboo.co.uk/2010/7/30/html5-powered-ajax-file-uploads](http://blog.new-bamboo.co.uk/2010/7/30/html5-powered-ajax-file-uploads)

This middleware should work with Ruby 1.8.7, 1.9.2, REE, Rubinius and JRuby. Tests for all these platforms are run on the wonderful [Travis-CI](http://travis-ci.org/) regularly, and the current status of these is: [![Build Status](http://travis-ci.org/newbamboo/rack-raw-upload.png)](http://travis-ci.org/newbamboo/rack-raw-upload)
