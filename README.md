# Running the site

    $ grunt serve

If that doesn't work for you, make sure you've done the one-time set up from this directory:

    $ npm install
    $ bundle install
    
If you don't have bundle, run

	$ gem install bundler
	
# Deploying the site

    $ grunt deploy

# Static files

If you want to upload anything for distribution, put it in _/srv/milessabin.com/public/htdocs/files_, which is mapped to _http://milessabin.com/files_.
