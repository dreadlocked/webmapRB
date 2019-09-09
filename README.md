### WebmapRB

A simple but useful web services enumerator for large infrastructures.

#### Dependencies

1. Ruby, of course.
2. If you doesn't already have bundler installed ```gem install bundler```
3. Nokogiri requires libxslt-dev and libxml2-dev. Also build-essential may be required.
4. ```bundle install``` (inside projects folder)

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
