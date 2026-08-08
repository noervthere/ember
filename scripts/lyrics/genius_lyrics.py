#!/usr/bin/env python3
import sys
import json
import re

def clean_genius_lyrics(lyrics_text):
    if not lyrics_text:
        return ""
    # Remove leading contributor info like "123 Contributors..."
    lines = lyrics_text.splitlines()
    if lines and "Contributor" in lines[0]:
        lines = lines[1:]
    
    text = "\n".join(lines)
    # Remove header text before title if present
    # Remove trailing Embed/number
    text = re.sub(r'\d*Embed$', '', text).strip()
    return text

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"found": False, "error": "Usage: genius_lyrics.py <artist> <title> [api_key]"}))
        sys.exit(1)

    artist = sys.argv[1]
    title = sys.argv[2]
    api_key = sys.argv[3] if len(sys.argv) > 3 else ""

    if not api_key or not api_key.strip():
        print(json.dumps({"found": False, "error": "No Genius API key provided"}))
        sys.exit(0)

    try:
        import lyricsgenius
        genius = lyricsgenius.Genius(
            api_key.strip(),
            verbose=False,
            remove_section_headers=False,
            skip_non_songs=True
        )
        song = genius.search_song(title, artist)
        if song and song.lyrics:
            lyrics = clean_genius_lyrics(song.lyrics)
            if lyrics:
                print(json.dumps({"found": True, "lyrics": lyrics}))
                return
        print(json.dumps({"found": False, "error": "No lyrics found"}))
    except Exception as e:
        print(json.dumps({"found": False, "error": str(e)}))

if __name__ == "__main__":
    main()
