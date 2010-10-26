# Tests for jhead-ruby

require "test/unit"
require "jhead"
require "../test/test_helper"

# In development,
# I always run everything from the lib/ directory.

class Jhead_test < Test::Unit::TestCase
  def setup
    @one_by_one    = Jhead.new f("1x1.jpg")
    @exif          = Jhead.new f("exif.jpg")
    @image         = Jhead.new f("image.jpg")
    @multiple_app1 = Jhead.new f("multiple-app1.jpg")
    @all           = Jhead.new f("*.jpg")
  end

  def test_many?
    assert !@one_by_one.many?
    assert @all.many?
  end

  def test_exif?
    assert !@one_by_one.exif?
    assert @exif.exif?
    assert !@image.exif?
    assert @multiple_app1.exif?
  end

  def test_data
    assert_kind_of Array, @all.data
    assert_kind_of Hash, @all.data.first
    assert_kind_of Hash, @one_by_one.data
    assert_kind_of Time, @one_by_one.data[:file_date]
    assert_kind_of Time, @exif.data[:date_time]
    assert_kind_of Array, @one_by_one.data[:resolution]

    assert_equal 100, @exif.data[:resolution].first
    assert_equal 100, @exif.width
    assert_equal "Canon PowerShot G3", @exif.data[:camera_model]
    assert_equal false, @exif.data[:flash_used]
    assert_equal "14.4mm  (35mm equivalent: 73mm)", @exif.data[:focal_length]
    assert_equal "Here's a comment!", @image.data[:comment]
  end

  def test_transplant_exif; end
  def test_delete_comment; end
  def test_delete_exif; end
  def test_delete_iptc; end
  def test_delete_xmp; end
  def test_delete_unknow; end
  def test_pure_jpg; end
  def test_make_exif; end
  def test_save_comment; end
  def test_load_comment; end
  def test_comment; end
  def test_update_system_time_stamp; end
  def test_update_exif_time_stamp; end
  def test_rename; end
  def test_adjust_time; end
  def test_adjust_date; end
  def test_date_time; end
  def test_delete_thumbnails; end
  def test_save_thumbnail; end
  def test_replace_thumbnail; end
  def test_regenerate_thumbnail; end
  def test_autorotate; end
  def test_clear_rotation_tag; end
  def test_match; end
end

