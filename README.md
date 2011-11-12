YouTube to MP3
==============

Screenshot
----------
[![http://gyazo.com/3e0722428c51ef049ef47534c096958f](http://gyazo.com/3e0722428c51ef049ef47534c096958f.png)](http://gyazo.com/3e0722428c51ef049ef47534c096958f)

Descriptin
----------
Download and convert YouTube's video to MP3

Requires
--------

 * ffmpeg

How to Use
----------

    git clone git://github.com/Cside/YouTube-to-MP3.crx.git
    cd YouTube-to-MP3.crx/

    cpanm Module::Install Module::Install::AuthorTests
    cpanm --installdeps .

	wget https://github.com/rg3/youtube-dl/raw/2011.10.19/youtube-dl
	sudo mv youtube-dl /usr/bin/
	sudo chmod +x /usr/bin/youtube-dl

	# and edit ./config file

	sqlite3 youtube_dl.db < db/dl_status.sql
	perl worker.pl
	
    plackup app.psgi

Author
------
id:Cside (@Cside_)


