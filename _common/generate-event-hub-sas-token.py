import sys    
import time
import urllib
from urllib.parse import quote
from urllib.parse import quote_plus
import hmac
import hashlib
import base64

def get_auth_token(eh_namespace, eh_name, eh_key):
    uri = quote_plus("https://{0}.servicebus.windows.net/{1}".format(eh_namespace, eh_name))
    eh_key = eh_key.encode('utf-8')
    expiry = str(int(time.time() + 10000))
    string_to_sign = (uri + '\n' + expiry).encode('utf-8')
    signed_hmac_sha256 = hmac.HMAC(eh_key, string_to_sign, hashlib.sha256)
    signature = quote(base64.b64encode(signed_hmac_sha256.digest()))
    return 'SharedAccessSignature sr={0}&sig={1}&se={2}&skn={3}'.format(uri, signature, expiry, "RootManageSharedAccessKey")

if __name__ == '__main__':
    print(get_auth_token(sys.argv[1], sys.argv[2], sys.argv[3]))
    sys.exit(0)