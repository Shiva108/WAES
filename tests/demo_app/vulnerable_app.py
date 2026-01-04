import http.server
import socketserver
import urllib.parse
import json
import time

PORT = 8080

class VulnerableHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urllib.parse.urlparse(self.path)
        path = parsed_path.path
        query = urllib.parse.parse_qs(parsed_path.query)

        # 1. Root Page
        if path == "/":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"""
            <html>
            <head><title>WAES Test Target</title>
            <link rel="stylesheet" href="/style.css">
            </head>
            <body>
                <h1>Welcome to WAES Test Target (Vulnerable)</h1>
                <p>This is a simulated vulnerable application for testing.</p>
                <ul>
                    <li><a href="/login">Login Page</a> (SQL Injection)</li>
                    <li><a href="/search?q=test">Search</a> (XSS)</li>
                    <li><a href="/admin">Admin Panel</a> (Protected/Hidden)</li>
                    <li><a href="/api/users">API Endpoint</a></li>
                </ul>
                <hr>
                <!-- Secret comment: TODO remove /backup directory -->
            </body>
            </html>
            """)
            return

        # 2. Simulated WAF Behavior
        user_agent = self.headers.get('User-Agent', '')
        if "sqlmap" in user_agent.lower() or "nikto" in user_agent.lower():
            # Simulate WAF block
            self.send_response(403)
            self.send_header("Content-type", "text/html")
            self.send_header("X-WAF-Protection", "Cloudflare") # Fake WAF header
            self.end_headers()
            self.wfile.write(b"""
            <html>
            <head><title>403 Forbidden</title></head>
            <body>
            <center><h1>403 Forbidden</h1></center>
            <hr><center>cloudflare-nginx</center>
            </body>
            </html>
            """)
            return

        # 3. Reflected XSS
        if path == "/search":
            q = query.get('q', [''])[0]
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            # VULNERABLE: Reflecting input without sanitization
            response = f"""
            <html><body>
            <h1>Search Results</h1>
            <p>You searched for: {q}</p>
            <p>No results found.</p>
            </body></html>
            """
            self.wfile.write(response.encode('utf-8'))
            return

        # 4. Login (SQLi Simulation)
        if path == "/login":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"""
            <html><body>
            <h1>Login</h1>
            <form method="POST">
                User: <input type="text" name="user"><br>
                Pass: <input type="password" name="pass"><br>
                <input type="submit" value="Login">
            </form>
            </body></html>
            """)
            return
            
        # 5. Hidden Directories (for gobuster)
        if path == "/backup" or path == "/backup/":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"<h1>Index of /backup</h1><ul><li>config.php.bak</li><li>db_dump.sql</li></ul>")
            return
            
        if path == "/admin":
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Access Denied")
            return

        # Default: 404
        self.send_response(404)
        self.end_headers()
        self.wfile.write(b"404 Not Found")

print(f"Starting WAES Test Server on port {PORT}...")
print(f"URL: http://localhost:{PORT}")

with socketserver.TCPServer(("", PORT), VulnerableHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        httpd.server_close()
