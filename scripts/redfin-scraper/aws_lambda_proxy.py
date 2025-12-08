"""
Enhanced AWS Lambda Function for Web Scraping Proxy
Includes proper headers, error handling, and response forwarding.
"""
import json
import urllib.request
import urllib.parse
import urllib.error

def lambda_handler(event, context):
    """
    Fetches a URL and returns the HTML content with proper error handling.
    """
    try:
        # Get target URL
        query_params = event.get('queryStringParameters', {})
        target_url = query_params.get('url')
        
        if not target_url:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Missing url parameter'})
            }
        
        target_url = urllib.parse.unquote(target_url)
        
        # Enhanced headers to look like a real browser
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'DNT': '1',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
            'Cache-Control': 'max-age=0'
        }
        
        req = urllib.request.Request(target_url, headers=headers)
        
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                # Read and decode content
                content = response.read()
                
                # Try to decode as UTF-8
                try:
                    html_content = content.decode('utf-8')
                except UnicodeDecodeError:
                    html_content = content.decode('latin-1', errors='ignore')
                
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'text/html; charset=utf-8',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': html_content
                }
        
        except urllib.error.HTTPError as e:
            # Return the actual HTTP error code
            return {
                'statusCode': e.code,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': f'HTTP {e.code}: {e.reason}',
                    'url': target_url
                })
            }
        
        except urllib.error.URLError as e:
            return {
                'statusCode': 502,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': f'URL Error: {str(e.reason)}',
                    'url': target_url
                })
            }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': f'Lambda Error: {str(e)}',
                'type': type(e).__name__
            })
        }