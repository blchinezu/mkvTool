# mkvTool
### Wrapper for mkvtoolnix written in Perl.

    Usage: mkvTool.pl <options>

    Options:
      target            <filepath|dirpath>
      audio    extract  <track1>:<lang1>[,<track2>:<lang2>]
      audio    keep     <track1>[,<track2>]
      chapter  clean
      set      language <track1>:<lang1>[,<track2>:<lang2>]
      subtitle add      <lang1>[,<lang2>]
      subtitle clean
      subtitle extract  <track1>:<lang1>[,<track2>:<lang2>]
      subtitle keep     <track1>[,<track2>]
      video    extract  <track1>[,<track2>]
      info
      remux
      nobackup
      preview

    OBS: remux can't be used with other options!
    
**Example:**

    brucelee@eris:~/test$ mkvTool.pl info chapter clean subtitle extract 1:en set language 0:en,2:en info target ./

    MKV: ./house.s08e01.576p.bluray.x264-hisd.mkv
    OPT: info
    CMD: /home/brucelee/bin/mkvTool.pl info ./house.s08e01.576p.bluray.x264-hisd.mkv

    File './house.s08e01.576p.bluray.x264-hisd.mkv': container: Matroska
    Track ID 0: audio (AC3/EAC3)
    Track ID 1: subtitles (SubRip/SRT)
    Track ID 2: video (MPEG-4p10/AVC/h.264)
    Tags for track ID 0: 7 entries
    Tags for track ID 1: 7 entries
    Tags for track ID 2: 7 entries

    MKV: ./house.s08e01.576p.bluray.x264-hisd.mkv
    OPT: chapter clean
    CMD: mkvpropedit ./house.s08e01.576p.bluray.x264-hisd.mkv -c ''

    The file is being analyzed.
    The changes are written to the file.
    Done.

    MKV: ./house.s08e01.576p.bluray.x264-hisd.mkv
    OPT: subtitle extract 1:en
    CMD: mkvextract tracks ./house.s08e01.576p.bluray.x264-hisd.mkv 1:./house.s08e01.576p.bluray.x264-hisd.en.srt

    Extracting track 1 with the CodecID 'S_TEXT/UTF8' to the file './house.s08e01.576p.bluray.x264-hisd.en.srt'. Container format: SRT text subtitles
    Progress: 100%

    MKV: ./house.s08e01.576p.bluray.x264-hisd.mkv
    OPT: set language 0:en,2:en
    CMD: mkvmerge --language 0:en --language 2:en ./house.s08e01.576p.bluray.x264-hisd.mkv -o ./house.s08e01.576p.bluray.x264-hisd.out.mkv

    mkvmerge v6.7.0 ('Back to the Ground') 64bit built on Jan  9 2014 18:03:17
    './house.s08e01.576p.bluray.x264-hisd.mkv': Using the demultiplexer for the format 'Matroska'.
    './house.s08e01.576p.bluray.x264-hisd.mkv' track 0: Using the output module for the format 'AC3'.
    './house.s08e01.576p.bluray.x264-hisd.mkv' track 1: Using the output module for the format 'text subtitles'.
    './house.s08e01.576p.bluray.x264-hisd.mkv' track 2: Using the output module for the format 'AVC/h.264'.
    The file './house.s08e01.576p.bluray.x264-hisd.out.mkv' has been opened for writing.
    Progress: 100%
    The cue entries (the index) are being written...
    Muxing took 6 seconds.

    mkdir ./backup/

    move(./house.s08e01.576p.bluray.x264-hisd.mkv, ./backup/house.s08e01.576p.bluray.x264-hisd.mkv)

    move(./house.s08e01.576p.bluray.x264-hisd.out.mkv, ./house.s08e01.576p.bluray.x264-hisd.mkv)

    MKV: ./house.s08e01.576p.bluray.x264-hisd.mkv
    OPT: info
    CMD: /home/brucelee/bin/mkvTool.pl info ./house.s08e01.576p.bluray.x264-hisd.mkv

    File './house.s08e01.576p.bluray.x264-hisd.mkv': container: Matroska
    Track ID 0: audio (AC3/EAC3) (English)
    Track ID 1: subtitles (SubRip/SRT) (English)
    Track ID 2: video (MPEG-4p10/AVC/h.264) (English)
    Tags for track ID 0: 7 entries
    Tags for track ID 1: 7 entries
    Tags for track ID 2: 7 entries

    Done!

    brucelee@eris:~/test$
