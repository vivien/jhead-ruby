# -----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <vivien.didelot@gmail.com> wrote this file. As long as you retain this notice
# you can do whatever you want with this stuff. If we meet some day, and you
# think this stuff is worth it, you can buy me a beer in return. Vivien Didelot
# -----------------------------------------------------------------------------
#
# This file is a wrapper for the jhead command line tool,
# written by Matthias Wandel.
# http://www.sentex.ca/~mwandel/jhead/
#
# Example:
#
#   photo = Jhead.new("photo.jpg")
#   photo.date_time # => Fri Aug 27 15:53:53 1000 2010
#
#   Jhead.new("photo.jpg") do |p|
#     p.date_time = Time.now
#   end
#
# Author:: Vivien Didelot (v0n) <vivien.didelot@gmail.com>

require "tempfile"

# Wrapper for jhead
class Jhead
  class JheadError < RuntimeError
    attr_reader :command

    def initialize(command = nil)
      @command = command
    end
  end

  # This wrapper version.
  JHEAD_RUBY_VERSION = "0.0.1"

  # jhead binary
  JHEAD_BINARY = "jhead"

  # Function to execute a jhead call to the system.
  # Pass jhead command line options in parameter.
  def Jhead.call(*args)
    cmd = args.unshift(JHEAD_BINARY) * " "
    cmd << " 2>&1"
    out = `#{cmd}`.strip
    raise(JheadError.new(cmd), out) if $?.exitstatus > 0
    out
  end

  # jhead version on the system.
  JHEAD_VERSION = Jhead.call("-V")[/(\d+.\d+)/]

  # jhead EXIF tags.
  TAGS = [
    :file_name,
    :file_size,
    :file_date,
    :camera_make,
    :camera_model,
    :date_time,
    :resolution,
    :orientation,
    :color_bw,
    :flash_used,
    :focal_length,
    :digital_zoom,
    :ccd_width,
    :exposure_time,
    :aperture,
    :focus_dist,
    :iso_equiv,
    :exposure_bias,
    :whitebalance,
    :light_source,
    :metering_mode,
    :exposure,
    :exposure_mode,
    :focus_range,
    :jpeg_process,
    :gps_latitude,
    :gps_longitude,
    :gps_altitude,
    :comment
  ]

  # Contructor.
  # pattern should be the targeted file(s), e.g. "*.jpg".
  # for matching options, see :match method.
  def initialize(pattern, match_opts = {})
    @pattern = pattern
    @match = ""
    self.match(match_opts) unless match_opts.empty?
    yield self if block_given?
  end

  def method_missing(method, *args) # :nodoc:
    super unless args.empty?
    super unless TAGS.include? method
    self.data[method]
  end

  def respond_to?(method) # :nodoc:
    super || TAGS.include?(method)
  end

  def methods # :nodoc:
    super + TAGS.map { |t| t.to_s }
  end

  # Get the count of targeted files.
  def count
    Jhead.call("-c", @match, @pattern).split("\n").size
  end

  # Ask if there is more than one file.
  def many?
    count > 1
  end

  # Ask if file has exif data.
  def exif?
    #TODO could be better?
    # Not good because it can rescues a file doesn't exist error.
    unless many?
      !Jhead.call("-exonly", "-c", @match, @pattern).empty? rescue false
    end
  end

  #TODO rename to self.exif or not? (<= remove filename, etc.)
  # Get all Jhead data from targeted file(s).
  # It will return a hash of info for a single file or an array of hashes.
  def data
    data = Jhead.call(@match, @pattern).split("\n\n").map { |p| p.split("\n") }
    data.map! do |p|
      h = Hash.new
      p.each do |l|
        # IMPROVE for the moment, ignore line:
        # "======= IPTC data: =======" and its following lines.
        break if l == "======= IPTC data: ======="
        if l =~ /(.+?)\s*:\s*(.+)/
          h[parse_tag $1] = parse_value $2
        end
      end
      h
    end

    data.size == 1 ? data.first : data
  end

  # Get the width of the jpeg file.
  def width
    self.resolution.first unless self.resolution.nil? || many?
  end

  # Get the height of the jpeg file.
  def height
    self.resolution.last unless self.resolution.nil? || many?
  end

  # Get a hash from the file.
  def to_hash
    data.merge(:width => width, :height => height) unless many?
  end

  # GENERAL METADATA METHODS

  # Transplant Exif header from image <name> into specified image.
  # This option is useful if you like to edit the photos but
  # still want the Exif header on your photos.
  # As most photo editing programs will wipe out the Exif header,
  # this option can be used to re-transplant them back
  # in after editing the photos.
  # This feature has an interesting 'relative path' option
  # for specifying the thumbnail name.
  # Whenever the <name> contains the characters '&i',
  # jhead will substitute the original filename for this name.
  # This allows creating a 'relative name' when doing a whole batch of files.
  #
  # For example, the incantation:
  #   Jhead.new("*.jpg").transplant_exif "originals\&i"
  # would transfer the Exif header for each .jpg file
  # in the originals directory by the same name,
  # Both Win32 and most UNIX shells treat the '&' character in a special way,
  # so you have to put quotes around that command line option
  # for the '&' to even be passed to the program.
  def transplant_exif(name)
    Jhead.call("-te", name.shellescape, @match, @pattern)
  end

  # Delete comment field from the JPEG header.
  # Note that the comment is not part of the Exif header.
  def delete_comment
    Jhead.call("-dc", @match, @pattern)
  end

  # Delete the Exif header entirely.
  # This leaves other sections (IPTC, XMP, comment) intact.
  def delete_exif
    Jhead.call("-de", @match, @pattern)
  end

  # Delete IPTC section (if present). Leaves other sections intact.
  def delete_iptc
    Jhead.call("-di", @match, @pattern)
  end

  # Delete XMP section (if present). Leaves other sections intact.
  def delete_xmp
    Jhead.call("-dx", @match, @pattern)
  end

  # Delete any sections that jhead doesn't know about.
  # Leaves Exif, XMP, IPTC and comment sections intact.
  def delete_unknown
    Jhead.call("-du", @match, @pattern)
  end

  # Delete all JPEG sections that aren't necessary for rendering the image.
  # Strips any metadata that various applications may have left in the image.
  # A combination of the delete_exif, delete_comment
  # and delete_unknown methods.
  def pure_jpg
    Jhead.call("-purejpg", @match, @pattern)
  end

  # Creates minimal Exif header.
  # Exif header contains date/time, and empty thumbnail fields only.
  # Date/time set to file time by default.
  # set the thumbnail option to true if you want the Exif header
  # to contain a thumbnail.
  # Note that Exif header creation is very limited at this time,
  # and no other fields can be added to the Exif header this way.
  def make_exif(thumbnail = false)
    option = thumbnail ? "-mkexif -rgt" : "-mkexif"
    Jhead.call(option, @match, @pattern)
  end

  # Save comment section to a file.
  def save_comment(name)
    Jhead.call("-cs", name.shellescape, @match, @pattern)
  end

  # Replace comment with text from file.
  def load_comment(name)
    Jhead.call("-ci", name.shellescape, @match, @pattern)
  end

  # Replace comment with comment from command line.
  def comment=(comment)
    Jhead.call("-cl", comment.shellescape, @match, @pattern)
  end

  # DATE / TIME MANIPULATION METHODS

  # Sets the file's system time stamp to what is stored in the Exif header.
  def update_system_time_stamp
    out = Jhead.call("-ft", "-q", @match, @pattern)
    raise(JheadError.new, out) unless out.empty?
  end

  # Sets the Exif timestamp to the file's timestamp.
  # Requires an Exif header to pre-exist.
  # set mkexif option to true to create one if needed.
  def update_exif_time_stamp(mkexif = false)
    make_exif if mkexif # Good idea or not?
    out = Jhead.call("-dsft", "-q", @match, @pattern)
    raise(JheadError.new, out) unless out.empty?
  end

  # This method causes files to be renamed and/or moved
  # according to the Exif header "DateTimeOriginal" field.
  # If the file is not an Exif file, or the DateTimeOriginal does not contain
  # a valid value, the file date is used.
  # Renaming is by default restricted to files whose names
  # consist largely of digits. This effectively restricts renaming
  # to files that have not already been manually renamed, as the default
  # sequential names from digital cameras consist largely of digits.
  #
  # Set the :force argument to true to force renaming of all files.
  # it will rename files regardless of original file name.
  #
  # If the name includes '/' or '\' (under windows),
  # this is interpreted as a new path for the file.
  # If the new path does not exist, the path will be created.
  #
  # If the format argument is omitted, the file will be renamed
  # to MMDD-HHMMSS. If a format argument is provided,
  # it will be passed to the strftime function for formatting.
  # In addition, if the format string contains '%f',
  # this will substitute the original name of the file (minus extension).
  # A sequence number may also be included by including '%i'
  # in the format string. Leading zeros can be specified.
  # '%03i' for example will pad the numbers to '001', '002'...
  # this works just like printf in C, but with '%i' instead of '%d'.
  # If the target name already exists, the name will be appended with
  # "a", "b", "c", etc, unless the name ends with a letter,
  # in which case it will be appended with "0", "1", "2", etc.
  # This feature is especially useful if more than one digital camera
  # was used to take pictures of an event. By renaming them to a scheme
  # according to date, they will automatically appear in order of taking
  # when viewed with some sort of viewer like Xnview or AcdSee,
  # and sorted by name. Or you could use the update_system_time_stamp method
  # and view the images sorted by date. Typically, one of the carera's date
  # will be set not quite right, in which case you may have to use
  # the adjust_time or adjust_date methods on those files first.
  #
  # Some of the more useful arguments for strftime are:
  # %d  Day of month as decimal number (01 – 31)
  # %H  Hour in 24-hour format (00 – 23)
  # %j  Day of year as decimal number (001 – 366)
  # %m  Month as decimal number (01 – 12)
  # %M  Minute as decimal number (00 – 59)
  # %S  Second as decimal number (00 – 59)
  # %U  Week of year as decimal number,
  # with Sunday as first day of week (00 – 53)
  # %w  Weekday as decimal number (0 – 6; Sunday is 0)
  # %y  Year without century, as decimal number (00 – 99)
  # %Y  Year with century, as decimal number
  #
  # Example:
  #   Jhead.new("*.jpg") do |files|
  #     files.rename("%Y%m%d-%H%M%S")
  #   end
  #
  # This will rename files matched by *.jpg according to YYYYMMDD-HHMMSS
  #
  # Note to Windows batch file users: '%' is used to deliminate
  # macros in Windows batch files. You must use %% to get one %
  # passed to the program. So from a batch file,
  # you would have to write "files.rename("%%Y%%m%%d-%%H%%M%%S")
  #TODO do this in Ruby?
  # For a full listing of strftime arguments, look up the strftime C function.
  # Note that some arguments to the strftime function (not listed here)
  # produce strings with characters such as '/' and ':' that may not be valid
  # as part of a filename on various systems.
  #
  # (Windows only option)
  # Set the :extension to true to rename files with the same name but
  # different extension as well. This is useful for renaming .AVI files
  # based on Exif file in .THM, or to rename sound annotation files
  # or raw files with jpeg files. Use together with '-n' option.
  def rename(arg = {:format => nil, :force => false, :extension => false})
    option = arg[:force] ? "-nf" : "-n"
    option << arg[:format] unless arg[:format].nil?
    option << " -a" if arg[:extension]
    Jhead.call(option, @match, @pattern)
  end

  def rename_like(format = nil, force = false)
    self.rename(:format => format, :force => force)
  end

  # Adjust time stored in the Exif header by h:mm backwards or forwards.
  # Useful when having taken pictures with the wrong time set on the camera,
  # such as after travelling across time zones,
  # or when daylight savings time has changed.
  # This option uses the time from the "DateTimeOriginal" (tag 0x9003) field,
  # but sets all the time fields in the Exif header to the new value.
  #
  # Examples:
  # Adjust time one hour forward (you would use this
  # after you forgot to set daylight savings time on the digicam)
  #
  #   Jhead.new("*.jpg").adjust_time("+1:00")
  #
  # Adjust time back by 23 seconds (you would use this to get the timestamps
  # from two digicams in sync after you found that they didn't quite align)
  #
  #   Jhead.new("*.jpg").adjust_time("-0:00:23")
  #
  # Adjust time forward by 2 days and 1 hour (49 hours)
  #
  #   Jhead.new("*.jpg").adjust_time("+49")
  #
  #IMPROVE find a better format for timediff parameter
  def adjust_time(timediff)
    Jhead.call("-ta" << timediff, @match, @pattern)
  end

  # Works like :adjust_time, but for specifying large date offsets,
  # to be used when fixing dates from cameras where
  # the date was set incorrectly, such as having date and time
  # reset by battery removal on some cameras. This feature is best for
  # adjusting dates on pictures taken over a large range of dates.
  # For pictures all taken the same date,
  # the :set_date method is often easier to use.
  #
  # Because different months and years have different numbers of days in them,
  # a simple offset for months, days, years would lead
  # to unexpected results at times. The time offset is thus specified
  # as a difference between two dates, so that jhead can figure out
  # exactly how many days the timestamp needs to be adjusted by,
  # including leap years and daylight savings time changes.
  # The dates are specified as yyyy:mm:dd. For sub-day adjustments,
  # a time of day can also be included,
  # by specifying yyyy:mm:dd/hh:mm or yyyy:mm:dd/hh:mm:ss
  #
  # Examples:
  # Year on camera was set to 2005 instead of 2004 for pictures taken in April
  #
  #   adjust_date("2005:03:01", "2004:03:01")
  #
  # Default camera date is 2002:01:01,
  # and date was reset on 2005:05:29 at 11:21 am
  #
  #   adjust_date("2005:05:29/11:21", "2002:01:01")
  #
  #IMPROVE params syntax
  def adjust_date(date1, date2)
    Jhead.call("-da" << date1 << '-' << date2, @match, @pattern)
  end

  # Sets the date and time stored in the Exif header to what is specified
  # on the command line. This option changes all the date fields
  # in the Exif header.
  def date_time=(time)
    Jhead.call("-ts" << time.strftime("%Y:%m:%d-%H:%M:%S"), @match, @pattern)
  end

  # Sets the date stored in the Exif header to what is specified
  # on the command line. Can be used to set date, just year and month,
  # or just year. Date is specified as:
  #   :year => yyyy
  # or
  #   :year => yyyy, :month => mm
  # or
  #   :year => yyyy, :month => mm, :day => dd
  #
  # Example:
  #   Jhead.new("pic01.jpg").set_date :year => 2010, :month => 10
  def set_date(date)
    param = date[:year]
    if date.key? :month
      param << ":" << date[:month]
      param << ":" << date[:day] if date.key? :day
    end
    Jhead.call("-ds" << param, @match, @pattern)
  end

  # THUMBNAIL MANIPULATION METHODS

  # Delete thumbnails from the Exif header, but leave
  # the interesting parts intact. This option truncates the thumbnail
  # from the Exif header, provided that the thumbnail is the last part
  # of the Exif header (which so far as I know is always the case).
  # Exif headers have a built-in thumbnail, which is typically 240x160
  # and 10k in size. This thumbnail is used by digital cameras.
  # Windows XP, as well as various photo viewing software may also use
  # this thumbnail if present, but work just fine if it isn't.
  def delete_thumbnails
    Jhead.call("-dt", @match, @pattern)
  end

  # Save the built in thumbnail from Jpegs that came from a digital camera.
  # The thumbnail lives inside the Exif header,
  # and is a very low-res JPEG image. Note that making any changes to a photo,
  # except for with some programs, generally wipes out the Exif header
  # and with it the thumbnail.
  # I implemented this option because I kept getting asked
  # about having such an option. I don't consider the built in thumbnails
  # to be all that useful - too low res. However, now you can see for yourself.
  # I always generate my thumbnails using ImageMagick (see end of this page).
  # Like the transplant_exif method, this feature has
  # the 'relative path' option for specifying the thumbnail name.
  # Whenever the <name> contains the characters '&i',
  # jhead will substitute the original filename for this name.
  # This allows creating a 'relative name' when doing a whole batch of files.
  # For example, the incantation:
  #
  #   Jhead.new("*.jpg").save_thumbnail("thumbnails\&i")
  #
  # would create a thumbnail for each .jpg file in the thumbnails directory by
  # the same name, (provided that the thumbnails directory exists, of course).
  # Both Win32 and most UNIX shells treat the '&' character in a special way,
  # so you have to put quotes around that command line option for the '&'
  # to even be passed to the program.
  #
  # (UNIX build only)
  # If STDOUT is specified for the output file, the thumbnail is sent to stdout.
  def save_thumbnail(name)
    name = "-" if name == STDOUT
    Jhead.call("-st", name.shellescape, @match, @pattern)
  end

  # Replace thumbnails from the Exif header. This only works
  # if the Exif header already contains an Exif header a thumbnail.
  def replace_thumbnail(name)
    Jhead.call("-rt", name.shellescape, @match, @pattern)
  end

  # Regnerate Exif thumbnail.
  # 'size' specifies maximum height or width of thumbnail.
  # I added this option because I had a lot of images that I had rotated
  # with various tools that don't update the Exif header.
  # But newer image browsers such as XnView make use of the Exif thumbnail,
  # and so the thumbnails would be different from the image itself.
  # Note that the rotation tag also needed to be cleared
  # (clear_rotation_tag method). Typically, only images that are shot
  # in portrait orientation are afflicted with this.
  # You can set the only_upright option to true to tell jhead to only
  # operate on images that are upright.
  #
  # This option relies on 'mogrify' program (from ImageMagick)
  # to regenerate the thumbnail. Linux users often already have this tool
  # pre-installed. Windows users have to go and download it.
  # This option only works if the image already contains a thumbnail.
  def regenerate_thumbnail(size = nil,
                           clear_rot_tag = false,
                           only_upright = false)
    option = "-rgt"
    option << size unless size.nil?
    option << " -norot" if clear_rotation_tag
    option << " -orp" if only_upright
    Jhead.call(option, @match, @pattern)
  end

  # ROTATION TAG MANIPULATION

  # Using the 'Orientation' tag of the Exif header,
  # rotate the image so that it is upright.
  # The program 'jpegtran' is used to perform the rotation.
  # This program is present in most Linux distributions.
  # For windows, you need to get a copy of it. After rotation,
  # the orientation tag of the Exif header is set to '1' (normal orientation).
  # The Exif thumbnail is also rotated. Other fields of the Exif header,
  # including dimensions are untouched, but the JPEG height/width are adjusted.
  # This feature is especially useful with newer digital cameras,
  # which set the orientation field in the Exif header automatically using
  # a built in orientation sensor in the camera.
  def auto_rotate
    Jhead.call("-autorot", @match, @pattern)
  end

  # Clears the Exif header rotation tag without altering the image.
  # You may find that your images have rotation tags in them from your camera,
  # but you already rotated them with some lossless tool
  # without clearing the rotation tag. Now your friendly browser rotates
  # the images on you again because the image rotation tag still indicates
  # the image should be rotated. Use this method to fix this problem.
  # You may also want to regenerate the thumbnail setting
  # the regen_thumbnail option to true.
  def clear_rotation_tag(regen_thumbnail = false)
    option = "-norot"
    option << " -rgt" if regen_thumbnail
    Jhead.call(option, @match, @pattern)
  end

  # FILE MATCHING AND SELECTION

  # Match specific files according to the options hash.
  # This should be set before executing an action method.
  #
  # * Set :model to a specific camera model to
  # restrict processing of files to those whose camera model,
  # as indicated by the Exif image information, contains the substring
  # specified.
  # For example, the following command will list
  # only images that are from an S100 camera:
  #
  #   Jhead.new("*.jpg").match(:model => "S100").data
  #
  # I use this option to restrict my JPEG re-compressing to those images
  # that came from my Canon S100 digicam, (see the :command method).
  #
  # * Set :exif_only to true to
  # skip all files that don't have an Exif header. This skips all files
  # that did not come directly from the digital camera,
  # as most photo editing software does not preserve the Exif header
  # when saving pictures.
  # * Set :portrait_only or :landscape_only to true to
  # operate only on images with portrait or landscape aspect ratio.
  # Please note that this is solely based on jpeg width and height values.
  # Some browsers may auto rotate the image on displaying it based
  # on the Exif orientation tag, so that images shot in portrait mode
  # are displayed as portrait. However, the image itself may not be stored
  # in portrait orientation. The auto_rotate and clear_rotation_tag methods
  # are useful for dealing with rotation issues.
  #
  # IMPROVE avoid redondant options
  def match(opts)
    if opts.empty?
      @match = ""
    else
      @match << " -model #{opts[:model]}" if opts.has_key? :model
      @match << " -exonly" if opts[:exif_only]
      @match << " -orp" if opts[:portrait_only]
      @match << " -orl" if opts[:landscape_only]
    end
  end

  # Executes the specified command on each JPEG file to be processed.
  #
  # The Exif section of each file is read before running the command,
  # and reinserted after the command finishes.
  #
  # The  specified command invoked separately for each JPEG that is processed,
  # even if multiple files are specified (explicitly or by wild card).
  #
  # Example use:
  #
  # Having a whole directory of photos from my S100,
  # I run the following commands:
  #
  #   photos = Jhead.new "*.jpg", :model => "S100"
  #   photos.command("mogrify -quality 80 &i")
  #   photos.match {}
  #   photos.command("jpegtran -progressive &i > &o")
  #
  # The first command mogrifies all JPEGs in the tree that indicate that
  # they are from a Canon  S100 in their Exif header to 80% quality
  # at the same resolution. This is a 'lossy' process,
  # so I only run it on files that are from the Canon, and only run it once.
  # The next command then takes a JPEGs and converts them to progressive JPEGs.
  # The result is the same images, with no discernible differences,
  # stored in half the space. This produces substantial savings on some cameras.
  def command(cmd)
    Jhead.call("-cmd", cmd, @match, @pattern)
  end

  private

  def parse_tag(str)
    tag = str.downcase.gsub(/[\s\/]/, '_').chomp('.').to_sym
    unless TAGS.include? tag
      # To avoid possibles mistakes between jhead output and the wrapper.
      raise(JheadError.new, "Tag ':#{tag}' (from '#{str}') not valid.")
    end
    tag
  end

  def parse_value(str)
    case str
    when /^(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)$/
      Time.mktime($1, $2, $3, $4, $5, $6) rescue nil
    when /^(No|Yes)$/ then $1 == "Yes"
    when /^(\d+) x (\d+)$/ then [$1.to_i, $2.to_i]
    else str
    end
  end

  # test. Useful?
  def write_with_temp
    unless many?
      #TODO Bad, because cannot cp a file to *.jpg e.g.
      tempfile = Tempfile.new("jhead").path
      FileUtils.cp(@pattern, tempfile)

      yield tempfile

      unless tempfile == @pattern
        #TODO not this test. find another one.
        raise(JheadError.new, "Writing went awry on temp file, cancelled.")
      end
      FileUtils.cp(tempfile, @pattern)
    end
  end
end
