import time
import urllib
from urllib.parse import quote
from urllib.parse import quote_plus
import hmac
import hashlib
import base64

def get_auth_token(sb_name, eh_name, sas_value):
    """
    Returns an authorization token dictionary 
    for making calls to Event Hubs REST API.
    """
    uri = quote_plus("https://{}.servicebus.windows.net/{}" \
                                  .format(sb_name, eh_name))
    sas = sas_value.encode('utf-8')
    expiry = str(int(time.time() + 10000))
    string_to_sign = (uri + '\n' + expiry).encode('utf-8')
    signed_hmac_sha256 = hmac.HMAC(sas, string_to_sign, hashlib.sha256)
    signature = quote(base64.b64encode(signed_hmac_sha256.digest()))
    return  'SharedAccessSignature sr={}&sig={}&se={}&skn={}' \
               .format(uri, signature, expiry, "RootManageSharedAccessKey")


if __name__ == '__main__':
    import sys
    # print("printing all values ",sys.argv[1], sys.argv[2], sys.argv[3])
    print(get_auth_token(sys.argv[1], sys.argv[2], sys.argv[3]))
    sys.exit(0)