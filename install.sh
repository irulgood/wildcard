#!/bin/bash

# Konfigurasi
DOMAIN="*.rinjanihost.com"   # Ganti dengan domain Anda
EMAIL="bryanhendery@gmail.com"  # Ganti dengan email Anda
CERTBOT_PATH="/usr/bin/certbot"  # Path Certbot (ubah jika berbeda)
CLOUDFLARE_CREDENTIALS="/etc/cloudflare.ini"  # Lokasi file kredensial Cloudflare
OUTPUT_PATH="/etc/letsencrypt/live/$DOMAIN"

# Fungsi untuk menginstal paket yang dibutuhkan
install_dependencies() {
    echo "Memperbarui daftar paket dan menginstal dependensi..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-dns-cloudflare
}

# Cek apakah Certbot sudah terinstal
if ! [ -x "$(command -v $CERTBOT_PATH)" ]; then
    echo "Certbot tidak ditemukan. Memulai instalasi..."
    install_dependencies
else
    echo "Certbot sudah terinstal."
fi

# Membuat file kredensial Cloudflare jika belum ada
if [ ! -f "$CLOUDFLARE_CREDENTIALS" ]; then
    echo "File kredensial Cloudflare tidak ditemukan. Membuat file baru..."
    
    # Meminta API token dari pengguna
    read -p "CVU8IyiQkeHSYBM9lLdr-Gb-7K0IyTPklawwu5H0: " API_TOKEN
    
    # Validasi input
    if [ -z "$API_TOKEN" ]; then
        echo "Error: API Token tidak boleh kosong."
        exit 1
    fi

    # Membuat file kredensial
    sudo bash -c "cat > $CLOUDFLARE_CREDENTIALS" <<EOL
dns_cloudflare_api_token = $API_TOKEN
EOL

    # Memberikan izin akses minimal pada file kredensial
    sudo chmod 600 $CLOUDFLARE_CREDENTIALS
    echo "File kredensial Cloudflare berhasil dibuat di $CLOUDFLARE_CREDENTIALS"
else
    echo "File kredensial Cloudflare ditemukan di $CLOUDFLARE_CREDENTIALS"
fi

# Memulai proses penerbitan sertifikat
echo "Memulai proses penerbitan sertifikat wildcard untuk $DOMAIN"
sudo $CERTBOT_PATH certonly --dns-cloudflare \
    --dns-cloudflare-credentials $CLOUDFLARE_CREDENTIALS \
    --email $EMAIL \
    --agree-tos \
    --non-interactive \
    -d "*.$DOMAIN" -d "$DOMAIN"

# Cek apakah sertifikat berhasil diterbitkan
if [ -d "$OUTPUT_PATH" ]; then
    echo "Sertifikat berhasil diterbitkan!"
    echo "Lokasi Sertifikat:"
    echo "Fullchain: $OUTPUT_PATH/fullchain.pem"
    echo "Private Key: $OUTPUT_PATH/privkey.pem"
else
    echo "Gagal menerbitkan sertifikat. Silakan cek log Certbot untuk detailnya."
    exit 1
fi

# Menambahkan pembaruan otomatis ke cron
echo "Menambahkan pembaruan otomatis ke cron..."
CRON_JOB="0 0 * * * $CERTBOT_PATH renew --quiet"
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Pembaruan otomatis telah ditambahkan ke cron."
echo "Selesai."
