#!/usr/bin/env ruby

require 'fileutils'
require 'pry'


def extract_from_file(filename)
  reading = false
  lines = []
  File.readlines(filename).each do |line|
    if !reading
      if line =~ /-- ?START LIB/i
        reading = true
      end
      next
    end
    return lines if line =~ /^-- ?END LIB/i
    lines << line
  end
  lines
end

tmp = File.open('out.tmp','w')
inserting = false
File.readlines('material_girl.p8').each do |line|
  if !inserting
    tmp << line
    if line =~ /-- ?START EXT ([^ ]+)\w*$/i
      extract_from_file($1.strip).each {|l| tmp << l }
      inserting = true
    end
  elsif line =~ /-- ?END EXT/i
    tmp << line
    inserting = false
  end
end
tmp.close
FileUtils.mv('out.tmp','material_girl.p8')






