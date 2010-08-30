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
  VERSION = "0.0.1"

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
    :apertude,
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

  def initialize(pattern)
    #TODO: should use @target = Dir[pattern]?
    @pattern = pattern
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

  def exif?
    #TODO
    true
  end

  def many?
    Dir[@pattern].size > 1
  end

  #TODO rename to self.exif or not? (<= remove filename, etc.)
  def data
    data = Jhead.call(@pattern).split("\n\n").map { |p| p.split("\n") }
    data.map! do |p|
      h = Hash.new
      p.each do |l|
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
    Jhead.call("-te", name, @pattern)
  end

  # Delete comment field from the JPEG header.
  # Note that the comment is not part of the Exif header.
  def delete_comment
    Jhead.call("-dc", @pattern)
  end

  # Delete the Exif header entirely.
  # This leaves other sections (IPTC, XMP, comment) intact.
  def delete_exif
    Jhead.call("-de", @pattern)
  end

  # Delete IPTC section (if present). Leaves other sections intact.
  def delete_iptc
    Jhead.call("-di", @pattern)
  end

  # Delete XMP section (if present). Leaves other sections intact.
  def delete_xmp
    Jhead.call("-dx", @pattern)
  end

  # Delete any sections that jhead doesn't know about.
  # Leaves Exif, XMP, IPTC and comment sections intact.
  def delete_unknown
    Jhead.call("-du", @pattern)
  end

  # Delete all JPEG sections that aren't necessary for rendering the image.
  # Strips any metadata that various applications may have left in the image.
  # A combination of the delete_exif, delete_comment
  # and delete_unknown methods.
  def pure_jpg
    Jhead.call("-purejpg", @pattern)
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
    Jhead.call(option, @pattern)
  end

  # Save comment section to a file.
  def save_comment(name)
    Jhead.call("-cs", name, @pattern)
  end

  # Replace comment with text from file.
  def load_comment(name)
    Jhead.call("-ci", name, @pattern)
  end

  # Replace comment with comment from command line.
  def comment=(comment)
    Jhead.call("-cl", comment, @pattern)
  end

  # DATE / TIME MANIPULATION METHODS

  # Sets the file's system time stamp to what is stored in the Exif header.
  def update_system_time_stamp
    out = Jhead.call("-ft", "-q", @pattern)
    raise(JheadError, out) unless out.empty?
  end

  # Sets the Exif timestamp to the file's timestamp.
  # Requires an Exif header to pre-exist.
  # set mkexif option to true to create one if needed.
  def update_exif_time_stamp(mkexif = false)
    make_exif if mkexif # Good idea or not?
    out = Jhead.call("-dsft", "-q", @pattern)
    raise(JheadError, out) unless out.empty?
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
  # the -ta or -da options on those files first.
  # TODO replace by corresponding method name
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
  # TODO do this in Ruby?
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
    Jhead.call(option, @pattern)
  end

  def rename_like(format = nil, force = false)
    self.rename(:format => format, :force => force)
  end

  # TODO
  def adjust_time(timediff)
    raise NotImplementedError
  end

  # TODO
  def adjust_date(date1, date2)
    raise NotImplementedError
  end

  def date_time=(time)
    Jhead.call("-ts" << time.strftime("%Y:%m:%d-%H:%M:%S"), @pattern)
  end

=begin
    def year=(time)
      if time.is_a? Time || time.is_a? Date # DateTime is a Date as well
        Command.ds time.strftime("%Y")
      else
        Command.ds time
      end
    end

    def year_month=(time)
      Command.ds time.strftime("%Y:%m")
    end

    def year_month_day=(time)
      Command.ds time.strftime("%Y:%m:%d")
    end

    def date=(yyyy, mm = nil, dd = nil)
      Command.ds yyyy.to_s << case dd || mm || yyyy
      when dd then "#{mm}:#{dd}" unless mm.nil?
      when mm then ":#{mm}" else ""
      end
    end
=end

  # THUMBNAIL MANIPULATION METHODS

  #TODO

  private

  def parse_tag(str)
    tag = str.downcase.gsub(/[\s\/]/, '_').chomp('.').to_sym
    unless TAGS.include? tag
      # To avoid possibles mistakes between jhead output and the wrapper.
      raise(JheadError, "Tag #{tag} (from #{str}) not valid.")
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

  def escape(str)
    "\"#{str}\""
  end

  # test. Useful?
  def write_with_temp
    unless many?
      #TODO. Bad, because cannot cp a file to *.jpg e.g.
      # should use @target = Dir[pattern] in constructor.
      tempfile = Tempfile.new("jhead").path
      FileUtils.cp(@pattern, tempfile)

      yield tempfile

      unless tempfile == @pattern
        #TODO not this test. find another one.
        raise(JheadError, "Writing went awry on temp file, cancelled.")
      end
      FileUtils.cp(tempfile, @pattern)
    end
  end
end
