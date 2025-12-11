# C2PA Signing Server

A local signing server for C2PA content authentication, built with Vapor.

## Features

- Remote signing API for C2PA manifests
- Certificate management
- Secure Enclave integration support (when running on macOS)
- RESTful API endpoints

## Running from Xcode

1. Open the main workspace: `C2PA.xcworkspace`
2. Select the **SigningServer** scheme from the scheme selector
3. Click Run (⌘R) to start the server
4. The server will start on `http://127.0.0.1:8080` by default

## Running from Command Line

```bash
cd signing-server
swift run SigningServer --port 8080 --host 127.0.0.1
```

## Command Line Options

- `--port, -p`: Port to listen on (default: 8080)
- `--host, -h`: Host to bind to (default: 127.0.0.1)
- `--certificate, -c`: Path to certificate file
- `--private-key, -k`: Path to private key file
- `--debug`: Enable debug logging

## API Endpoints

### POST /sign
Sign content with C2PA manifest

### GET /certificate
Get the server's certificate chain

### POST /csr
Generate a certificate signing request

## Development

The server uses:
- **Vapor 4** - Web framework
- **Swift Certificates** - X.509 certificate handling
- **Swift Crypto** - Cryptographic operations
- **C2PA** - Content authentication library

## Environment Variables

- `LOG_LEVEL`: Set to `debug`, `info`, `warning`, or `error`
- `SERVER_PORT`: Override default port
- `SERVER_HOST`: Override default host