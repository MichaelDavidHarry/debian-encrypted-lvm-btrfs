# debian-encrypted-lvm-btrfs
A script to use during the Debian Installer to create an encrypted Btrfs root with subvolumes and snapper snapshots on LVM.

## To Use:

1. During the Debian Installer process at the 'Load installer components from CD' step, select the 'network-console' component. Continue.
2. Enter a remote installation password, and choose continue.
3. Use SSH to connect to the installer.
4. Choose 'Start installer' or 'Start installer (expert mode)'.
5. Continue through the installation until the 'Partition disks' step.
6. Choose 'Manual' partitioning, and then create a single partition on the disk. Set up this partition as the root partition, and choose any normal root filesystem such as Ext4.
7. Choose 'Finish partitioning and write changes to disk'. The installer will ask if you want to go back and set up swap space, choose 'No' when it asks if you want to return to the partitioning menu.
8. Choose 'Yes' to write the changes to the disks on the next dialog.
9. Open another SSH session to the installer. Choose 'Start shell', and then 'Continue'.
10. Use nano to paste in the contents of the debian-encrypted-lvm-with-btrfs.sh script and save the file as run.sh. Run `chmod +x run.sh` to make the file executable.
11. Run run.sh and follow the instructions that come up on screen.