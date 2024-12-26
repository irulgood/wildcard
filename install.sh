#!/bin/bash

# Konfigurasi
DOMAIN="rinjanihost.com"   # Ganti dengan domain Anda
EMAIL="bryanhendery@gmail.com"  # Ganti dengan email Anda
CERTBOT_PATH="/usr/bin/certbot"  # Path Certbot
CLOUDFLARE_CREDENTIALS="/etc/cloudflare.ini"  # Lokasi file kredensial Cloudflare

# Fungsi untuk menginstal dependensi
install_dependencies() {
    echo "Memperbarui daftar paket dan menginstal dependensi..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-dns-cloudflare
}

# Fungsi untuk membuat file kredensial Cloudflare
create_cloudflare_credentials() {
    echo "Membuat file kredensial Cloudflare..."

    # Pilih metode autentikasi
    echo "Pilih metode autentikasi Cloudflare:"
    echo "1. API Token (Direkomendasikan)"
    echo "2. Global API Key"
    read -p "Masukkan pilihan Anda (1/2): " METHOD

    case $METHOD in
        1)
            read -p "Masukkan API Token Anda: " API_TOKEN
            if [ -z "$API_TOKEN" ]; then
                echo "Error: API Token tidak boleh kosong."
                exit 1
            fi
            sudo bash -c "cat > $CLOUDFLARE_CREDENTIALS" <<EOL
dns_cloudflare_api_token = $API_TOKEN
EOL
            ;;
        2)
            read -p "Masukkan email Cloudflare Anda: " CLOUDFLARE_EMAIL
            read -p "Masukkan Global API Key Anda: " API_KEY
            if [ -z "$CLOUDFLARE_EMAIL" ] || [ -z "$API_KEY" ]; then
                echo "Error: Email dan API Key tidak boleh kosong."
                exit 1
            fi
            sudo bash -c "cat > $CLOUDFLARE_CREDENTIALS" <<EOL
dns_cloudflare_email = $CLOUDFLARE_EMAIL
dns_cloudflare_api_key = $API_KEY
EOL
            ;;
        *)
            echo "Pilihan tidak valid. Keluar."
            exit 1
            ;;
    esac

    # Atur izin file kredensial
    sudo chmod 600 $CLOUDFLARE_CREDENTIALS
    echo "File kredensial Cloudflare berhasil dibuat di $CLOUDFLARE_CREDENTIALS"
}

# Periksa apakah Certbot sudah terinstal
if ! [ -x "$(command -v $CERTBOT_PATH)" ]; then
    echo "Certbot tidak ditemukan. Memulai instalasi..."
    install_dependencies
else
    echo "Certbot sudah terinstal."
fi

# Periksa apakah file kredensial Cloudflare sudah ada
if [ ! -f "$CLOUDFLARE_CREDENTIALS" ]; then
    echo "File kredensial Cloudflare tidak ditemukan."
    create_cloudflare_credentials
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
OUTPUT_PATH="/etc/letsencrypt/live/$DOMAIN"
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
