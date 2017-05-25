#!/bin/ruby

Dir.chdir "_site"

require "aws-sdk"
require "digest"
require "zlib"
require "mime-types"

SITE_PREFIX = ENV["SITE_PREFIX"]
BUCKET = ENV["BUCKET"]

S3 = Aws::S3::Client.new(
  access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  region: ENV["AWS_DEFAULT_REGION"],
)

DOTFILE_REGEX = /(\/|^)\..*/

def local_files
  @local_objects ||= Dir["**/*"].reject do |file|
    # Remove directories and dotfiles
    File.directory?(file) || file.match(DOTFILE_REGEX)
  end
end

def remote_objects
  if @remote_objects
    return @remote_objects
  end

  @remote_objects = []

  results_truncated = true
  continuation_token = nil

  while results_truncated do
    s3_response = S3.list_objects_v2(
      prefix: SITE_PREFIX,
      bucket: BUCKET,
      continuation_token: continuation_token,
      max_keys: 1000,
    )
    @remote_objects = @remote_objects + s3_response.contents
    results_truncated = s3_response.is_truncated
    if s3_response.is_truncated
      continuation_token = s3_response.next_continuation_token
    end
  end
  @remote_objects
end

def remote_object_filenames
  remote_objects.map do |object|
    object.key.gsub("#{SITE_PREFIX}/", "")
  end
end

puts "Compressing local files"

def should_compress_file?(filename)
  filename.match(GZIP_REGEX)
end

GZIP_REGEX = /\.html$|\.css$|\.js$|\.json$|\.svg$/
local_files.each do |filename|
  if !should_compress_file?(filename)
    next
  end

  contents = File.read(filename)
  Zlib::GzipWriter.open(filename) do |gz|
    # Spoof the modification time so that MD5 hashes match next time
    gz.mtime = Time.parse("March 19, 2014").to_i
    gz.write contents
  end
end

puts "Preparing to upload"

new_files = local_files - remote_object_filenames
deleted_files = remote_object_filenames - local_files

changed_files = remote_objects.map do |object|
  local_filename = object.key.gsub("#{SITE_PREFIX}/", "")
  etag = object.etag.gsub("\"", "")
  if File.exist?(local_filename) && etag != Digest::MD5.file(local_filename).to_s
    local_filename
  end
end.compact

puts "New files: #{new_files.length}"
puts "Modified files: #{changed_files.length}"
puts "Deleted files: #{deleted_files.length}"
puts "--------------------------"

(new_files + changed_files).each do |filename|
  print "Uploading: #{filename}... "
  start_time = Time.now

  content_encoding = "gzip" if should_compress_file?(filename)

  content_type = nil
  if mime_type = MIME::Types.type_for(filename).first
    content_type = mime_type.content_type
  end

  S3.put_object(
    body: File.open(filename),
    bucket: BUCKET,
    cache_control: ENV["CACHE_CONTROL"],
    content_encoding: content_encoding,
    content_type: content_type,
    server_side_encryption: "AES256",
    key: "#{SITE_PREFIX}/#{filename}",
  )

  puts "Done (#{Time.now - start_time}s)"
end

deleted_files.each do |filename|
  print "Deleting: #{filename}... "
  start_time = Time.now

  S3.delete_object(
    bucket: BUCKET,
    key: "#{SITE_PREFIX}/#{filename}",
  )

  puts "Done (#{Time.now - start_time}s)"
end
