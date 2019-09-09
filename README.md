### WebmapRB

A simple but useful web services enumerator for large infrastructures. WebmapRB expects a list of domains or ips inside a file (they can be mixed and IPs can be in CIDR format).

#### Dependencies

1. Ruby, of course.
2. If you doesn't already have bundler installed ```gem install bundler```
3. ```bundle install``` (inside projects folder)

It's usually as simple as this, but if you have system library issues then try to do and repeat step 3:

```apt install build-essential libcurl3 libcurl3-gnutls libcurl4-openssl-dev libxml2-dev libxslt-dev```

#### Usage

```
Usage: webmap.rb -f example.ranges [options]
    -f FILE_NAME                     Specifies the file name with domains and IPs deparated by new line.
        --csv                        Extract all the information on CSV files.
        --fast                       Scans just 80, 443 and 8080 ports
        --threads INT                Number of threads (Default: 30)
    -t, --timeout INT                Seconds for timeout (Default: 6)
    -v                               A bit of verbosity
    -h, --help                       Prints this help
```
