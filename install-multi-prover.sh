#!/bin/bash

# Pastikan script dijalankan tanpa root
if [[ $EUID -eq 0 ]]; then
   echo "Jangan jalankan script ini sebagai root!"
   exit 1
fi

# Meminta jumlah prover yang ingin dibuat
read -p "Masukkan jumlah prover yang ingin dijalankan: " num_accounts

# Pastikan input adalah angka
if ! [[ "$num_accounts" =~ ^[0-9]+$ ]]; then
    echo "Masukkan angka yang valid!"
    exit 1
fi

# Instalasi Supervisor jika belum ada
sudo apt update && sudo apt install -y supervisor curl

# Loop untuk membuat multiple prover
for i in $(seq 1 $num_accounts); do
    read -p "Masukkan EVM Address untuk Prover $i: " evm_address

    # Validasi format EVM Address
    if ! [[ "$evm_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "EVM Address tidak valid! Masukkan format yang benar."
        exit 1
    fi

    prover_dir="$HOME/cysic-prover-$i"
    mkdir -p "$prover_dir"

    echo "🔄 Mengatur Prover $i di $prover_dir dengan Address: $evm_address ..."

    # Install Cysic Prover
    curl -L github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_prover.sh > "$prover_dir/setup_prover.sh"
    bash "$prover_dir/setup_prover.sh" "$evm_address"

    # Download parameter files
    mkdir -p "$prover_dir/.scroll_prover/params"
    curl -L --retry 999 -C - circuit-release.s3.us-west-2.amazonaws.com/setup/params20 -o "$prover_dir/.scroll_prover/params/params20"
    curl -L --retry 999 -C - circuit-release.s3.us-west-2.amazonaws.com/setup/params24 -o "$prover_dir/.scroll_prover/params/params24"
    curl -L --retry 999 -C - circuit-release.s3.us-west-2.amazonaws.com/setup/params25 -o "$prover_dir/.scroll_prover/params/params25"

    # Konfigurasi Supervisor untuk setiap prover
    supervisor_conf="$HOME/supervisord-$i.conf"

    echo "[program:cysic-prover-$i]
command=$prover_dir/prover
numprocs=1
directory=$prover_dir
priority=999
autostart=true
redirect_stderr=true
stdout_logfile=$prover_dir/cysic-prover.log
stdout_logfile_maxbytes=1GB
stdout_logfile_backups=1
environment=LD_LIBRARY_PATH=\"$prover_dir\",CHAIN_ID=\"534352\"
" > "$supervisor_conf"

    # Menjalankan supervisord untuk prover ini
    supervisord -c "$supervisor_conf"
done

echo "✅ Semua Prover telah diinstal dan berjalan!"
echo "Cek logs dengan: supervisorctl tail -f cysic-prover-1 (ubah angka untuk prover lain)"
