#!/bin/bash

if [ "$1" = "--help" ]; then
        echo "usage: rollback.sh config snapshot-id"
        exit 1
fi

config="$1"
snapshot_id="$2"

subvol_dir_name="@$config"

if [ "$config" = "root" ]; then
        subvol_dir_name="@"
fi

sudo mv /.btrfs/$subvol_dir_name /.btrfs/$subvol_dir_name-old
sudo btrfs subvol snapshot /.btrfs/$subvol_dir_name-snapshots/$snapshot_id/snapshot /.btrfs/$subvol_dir_name
