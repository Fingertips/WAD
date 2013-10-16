# WAD

WAD is a little script that replaces the usual `bundle install` on Travis-CI. It installs the bundle and uploads it to Amazon S3 to speed up consecutive runs.

## Using WAD

### Get the WAD script

Download the script and put it in your project. It doesn't really matter where you store it. We assume you're using `bin/` in the following examples.

    $ curl -o bin/wad https://raw.github.com/Fingertips/WAD/master/bin/wad

Now make the script executable.

    $ chmod +x bin/wad

Add and commit it to your source repository.

### Build configuration

Travis-CI offers a number of configuration options for stuff that can ran around the build. The actual building should happen with the `script` key.

    script: bundle exec rake test:all
 
Before this happens we need to keep Travis-CI from installing the bundle and do it ourselves.
 
    install: "bin/wad"
    script: "bundle exec rake test:all"

Please refer to the Travis documentation if you need to do something more elaborate.

### Alternative build configuration

If you always want to run the latest version of WAD, you can set it up like this:

    install: "curl https://raw.github.com/Fingertips/WAD/master/bin/wad | ruby"
    script: "bundle exec rake test:all"

Note that this opens up an attack vector! For example, if someone manages to poision the DNS server used by Travis they can run arbitrary code.

### Environment

The WAD script needs to know where and how to access S3. You can do this with three environment variables. The S3 region, the bucket name and the S3 credentials.

The region and bucket name are relatively easy:

    env:
      global:
        - S3_REGION=eu-west-1
        - S3_BUCKET_NAME=unique-wad-bucket-name

You don't have to configure the region if you're using `eu-west-1`, the default.

The hard part is configuring the credentials, because they need to be signed. First concatenate your key and secret separated by a semicolon, like so:

    XXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

Then you use the Travis-CI command line utility to sign it. Replace `account/reponame` with the same GitHub account and repository name you've configured on Travis-CI.

     $ travis encrypt S3_CREDENTIALS="XXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" --repo account/reponame

When all of that is done, you should end up with something like this:

    install: "bin/wad"
    script: "bundle exec rake test:all"
    env:
      global:
        - S3_BUCKET_NAME=unique-wad-bucket-name
        - S3_REGION=eu-west-1
        - secure: "OTpNPEmXlMm70P4y6sE419Rr…"

If you're already using other encrypted variables you can add another `secure` key to the configuration or re-encrypt all of the settings. Please read Travis-CI documentation to figure out how that works. Good luck!

### Setting up S3

WAD doesn't automatically create a bucket for you. Please create one with the AWS console or the S3 tool of your choice.

### Retries

In some cases you can get network errors on Travis. Currently WAD does not retry bundle uploads or downloads. You can use the `travis_retry` tool if you run into this often:

    install: travis_retry bin/wad

### Cleaning up

Note that WAD **doesn't clean up** old bundles for you. If you change Gemfile.lock a lot and the bucket becomes very large, you probably want to clean out old bundles once in a while.

### Example

WAD uses itself to run itself on Travis, you can check out our [Travis configuration](https://github.com/Fingertips/WAD/blob/master/.travis.yml) and the [CI output](https://travis-ci.org/Fingertips/WAD).

## Q & A

#### Why isn't this a gem?

There are two reasons:

1. Installing gems is relatively slow and would unnecessarily slow down the build.
2. We wanted WAD to be completely standalone and only require the Ruby stdlib.

#### Why is the sky blue?

[Because shorter wavelengths of the visible light spectrum get scattered more in our atmosphere](http://spaceplace.nasa.gov/blue-sky/).

#### Why is water wet?

[It just happens to be the sensory perception you get when touching liquids](http://www.planet-science.com/categories/under-11s/our-world/2012/02/why-is-water-wet.aspx).

## Thanks!

We were inspired to write this little script through posts by [Matias Korhonen](http://randomerrata.com/post/45827813818/travis-s3) and [Michał Czyż](https://coderwall.com/p/x8exja).

## Copying

WAD is freely distributable under the terms of an MIT-style license. See COPYING or http://www.opensource.org/licenses/mit-license.php.