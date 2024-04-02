# Alipan files Cleaner

If you are using free account of alipan, it limited drive disk, you can use this script to force remove file(s) in given folder id.

## Usage

### Docker

```bash
docker run -d --name aliyun-files-cleaner \
  -e ALIPAN_REFRESH_TOKEN=abcedfg \
  -e ALIPAN_FOLDER_ID=123456789 \
  -e ALIPAN_RUNNER_INTERVAL=3600 \
  -e LOGGER_LEVEL=info \
  gchr.io/icyleaf/aliyun-files-cleaner
```

## Output

### All good

```
I, [2024-04-02T17:08:18.200467 #13058]  INFO -- : Starting alipan resources runner ...
I, [2024-04-02T17:08:18.200518 #13058]  INFO -- : cli v0.1.0, interval: 300 seconds, dry_mode: true
I, [2024-04-02T17:08:18.592409 #13058]  INFO -- : Disk information total: 102.9 GB, used: 23.06 GB, free: 79.84 GB
I, [2024-04-02T17:08:18.592463 #13058]  INFO -- : Fetching files from drive_id 123456789
I, [2024-04-02T17:08:18.701069 #13058]  INFO -- : Prepare to delete 1 file(s) ...
I, [2024-04-02T17:08:18.701121 #13058]  INFO -- : Deleting file: Taylor.Swift.Reputation.Stadium.Tour.2018.2160p.NF.WEB-DL.DDP5.1.Atmos.DV.HDR.H.265-CRFW.mkv (17.44 GB)
I, [2024-04-02T17:08:18.815700 #13058]  INFO -- : Result: cleaned disk 17.44 GB.
I, [2024-04-02T17:08:18.815753 #13058]  INFO -- : Waiting next loop ... (300 seconds)
```

### Found issue

```
I, [2024-04-02T17:08:18.200467 #13058]  INFO -- : Starting alipan resources runner ...
I, [2024-04-02T17:08:18.200518 #13058]  INFO -- : cli v0.1.0, interval: 300 seconds, dry_mode: true
E, [2024-04-02T16:39:46.200284 #29558] ERROR -- : Invalid refresh token, Try to fetch a new one:  https://aliyundriver-refresh-token.vercel.app/
```
