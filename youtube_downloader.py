import yt_dlp as youtube_dl

def download_video(url):
    ydl_opts = {
        'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
        'outtmpl': 'D:/download/%(title)s.%(ext)s',
        'subtitleslangs': ['en'],
        'writeautomaticsub': True,
    }

    def hook(d):
        if d['status'] == 'downloading':
            print(f"下载进度: {d['downloaded_bytes'] / d['total_bytes'] * 100:.2f}%")
        elif d['status'] == 'finished':
            print(f"下载完成: {d['filename']}")

    with youtube_dl.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

if __name__ == '__main__':
    video_url = str(input("请输入视频URL: "))
    download_video(video_url)
