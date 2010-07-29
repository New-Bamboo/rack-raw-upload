# Rack Raw Upload middleware

Rack::RawUpload converts files uploaded with mimetype `application/octect-stream` into normal form input, so Rack applications can read these as normal, rather than as raw input.

# Configuration

    use Rack::RawUpload, :paths => ['/upload/path', '/alternative/path.*']

# Assumtions

Rack::RawUpload expects that requests will:

1. be POST requests
2. set the mimetype `application/octect-stream`
