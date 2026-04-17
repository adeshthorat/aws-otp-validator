import os
import logging
import logging.handlers
from http.server import HTTPServer, SimpleHTTPRequestHandler
import urllib.request
import urllib.error
from datetime import datetime
import time

# Configure logging
log_dir = '/var/logs'
log_file = os.path.join(log_dir, 'app.log')

# Create log directory if it doesn't exist
if not os.path.exists(log_dir):
    try:
        os.makedirs(log_dir, exist_ok=True)
    except Exception:
        log_file = 'app.log'  # Fallback to local directory

# Setup logger
logger = logging.getLogger('OTPProxyServer')
logger.setLevel(logging.DEBUG)

# File handler (rotating)
try:
    file_handler = logging.handlers.RotatingFileHandler(
        log_file, maxBytes=10*1024*1024, backupCount=5
    )
except Exception:
    file_handler = logging.handlers.RotatingFileHandler(
        'app.log', maxBytes=10*1024*1024, backupCount=5
    )

file_handler.setLevel(logging.DEBUG)

# Console handler
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)

# Formatter
formatter = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
file_handler.setFormatter(formatter)
console_handler.setFormatter(formatter)

# Add handlers
logger.addHandler(file_handler)
logger.addHandler(console_handler)

logger.info("="*80)
logger.info("OTP Proxy Server Started")
logger.info(f"Log file location: {log_file}")
logger.info("="*80)

class CORSProxyHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        """Override to use our logger instead of stderr"""
        logger.info(f"{self.address_string()} - {format % args}")

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header("Access-Control-Allow-Headers", "X-Requested-With, Content-Type, Accept")
        SimpleHTTPRequestHandler.end_headers(self)

    def do_OPTIONS(self):
        client_ip = self.client_address[0]
        logger.info(f"[OPTIONS] IP: {client_ip} | Path: {self.path}")
        self.send_response(200, "ok")
        self.end_headers()
        logger.info(f"[OPTIONS] Response: 200 OK")

    def do_POST(self):
        client_ip = self.client_address[0]
        request_time = datetime.now().isoformat()
        start_time = time.time()
        
        logger.info("="*80)
        logger.info(f"[POST] Incoming Request")
        logger.info(f"  Client IP: {client_ip}")
        logger.info(f"  Timestamp: {request_time}")
        logger.info(f"  Path: {self.path}")
        logger.info(f"  Method: POST")
        logger.info(f"  Headers: {dict(self.headers)}")
        
        if self.path.startswith('/'):
            # Proxy to AWS API Gateway
            # Remove leading slash to get the endpoint path
            endpoint = self.path.lstrip('/')
            target_url = f"https://fwg9vxcpt0.execute-api.us-east-1.amazonaws.com/Prod/{endpoint}"
            
            logger.info(f"  Target URL: {target_url}")
            
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            logger.debug(f"  Request Body Size: {len(post_data)} bytes")

            req = urllib.request.Request(target_url, data=post_data, method='POST')
            req.add_header('Content-Type', self.headers.get('Content-Type', 'application/json'))

            try:
                logger.info(f"  Forwarding request to AWS...")
                response = urllib.request.urlopen(req)
                response_body = response.read()
                status_code = response.getcode()
                
                elapsed_time = time.time() - start_time
                logger.info(f"  AWS Response: {status_code}")
                logger.info(f"  Response Body Size: {len(response_body)} bytes")
                logger.info(f"  Elapsed Time: {elapsed_time:.3f}s")
                
                self.send_response(status_code)
                for k, v in response.headers.items():
                    if k.lower() not in ['transfer-encoding', 'connection', 'access-control-allow-origin']:
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(response_body)
                
                logger.info(f"  Sent response to client {client_ip}")
                logger.info("="*80)
                
            except urllib.error.HTTPError as e:
                response_body = e.read()
                status_code = e.code
                elapsed_time = time.time() - start_time
                
                logger.warning(f"  AWS HTTP Error: {status_code}")
                logger.warning(f"  Error Body: {response_body.decode('utf-8', errors='ignore')}")
                logger.warning(f"  Elapsed Time: {elapsed_time:.3f}s")
                
                self.send_response(status_code)
                for k, v in e.headers.items():
                    if k.lower() not in ['transfer-encoding', 'connection', 'access-control-allow-origin']:
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(response_body)
                
                logger.info(f"  Sent error response to client {client_ip}")
                logger.info("="*80)
                
            except Exception as e:
                elapsed_time = time.time() - start_time
                logger.error(f"  Exception during request: {str(e)}")
                logger.error(f"  Exception Type: {type(e).__name__}")
                logger.error(f"  Elapsed Time: {elapsed_time:.3f}s", exc_info=True)
                
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode('utf-8'))
                
                logger.info(f"  Sent 500 error to client {client_ip}")
                logger.info("="*80)
        else:
            logger.warning(f"  Invalid path: {self.path}")
            self.send_response(404)
            self.end_headers()
            logger.info("="*80)

if __name__ == '__main__':
    server_address = ('', 8000)
    httpd = HTTPServer(server_address, CORSProxyHandler)
    logger.info("Starting OTP Proxy Server on port 8000")
    logger.info("CORS enabled for all origins")
    logger.info("Proxy mode: Forwarding /otp/* requests to AWS API Gateway")
    print("Serving at port 8000 (Proxy mode enabled)")
    print(f"Logs available at: {log_file}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server shutdown requested")
    finally:
        httpd.server_close()
        logger.info("Server closed")
