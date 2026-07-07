---------------------------- Root CA Certificate --------------------
[a] Create a rootCA key: openssl genrsa -out rootCA.key 4096

[b] Create rootCA Certificate: openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.pem -subj "/C=IN/ST=WestBengal/L=Kolkata/O=MyLocalCA/CN=MyLocalRootCA"

Note: Replace subject as required

----------------------------- Generate CSR Certificate ---------------------
[a] Create domain key: openssl genrsa -out domain.key 2048

[b] Create CSR: openssl req -new -key domain.key -out domain.csr -subj "/C=IN/ST=WestBengal/L=Kolkata/O=MyCompany/CN=yourdomain.local"

[c] Create a SAN extension file: vim domain.ext

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = yourdomain.local
DNS.2 = *.yourdomain.local
IP.1 = 127.0.0.1

----------------------------- Sign Domain Certificate -------------------------------
[a] Sign the domain certificate: openssl x509 -req -in domain.csr -CA rootCA.pem -CAkey rootCA.key \
  -CAcreateserial -out domain.crt -days 825 -sha256 -extfile domain.ext


----------------------------- Combine into pem bundle ---------------------------------------
[a] Combine: cat domain.crt rootCA.pem > ssl-bundle.pem

------------------------------ Verify ----------------------------------------------------------
[a] Verify the certificate: openssl verify -CAfile rootCA.pem ssl-bundle.pem

