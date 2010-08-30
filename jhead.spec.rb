photo = Jhead.new("0805-153933.jpg")

photo.file_name # => 0805-153933.jpg
photo.file_size # => 463023 bytes
photo.file_date # => 2001:08:12 21:02:04
photo.camera_make # => Canon
photo.camera_model # => Canon PowerShot S100

photo.data.class # => Hash
photo.data[:date_time] # => 2001:08:05 15:39:33
photo.data[:camera_model] # => Canon PowerShot S100

photos = Jhead.new("~/*.jpg")
photos.data.class # => Array
photos.data.first.class # => Hash
