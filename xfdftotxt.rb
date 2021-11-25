#!/usr/bin/env ruby
# text extractor for Acrobat XFDF (note dump)
# Copyright (c) 2012-2021 Kenshi Muto <kmuto@debian.org>.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the University nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# Usage:
# xfdftotxt.rb FILE > DUMPFILE
# OFF=startnombre xfdftotxt.rb FILE > DUMPFILE

require 'rexml/document'
require 'rexml/streamlistener'
include REXML

class XFDFListener
  include StreamListener
  def initialize(offset)
    @offset = offset
    @para = nil
    @page = nil
    @name = nil # id
    @title = nil # commenter
    @date = nil
    @location = nil
    @inreplyto = nil
    @inpara = nil
    @items = []
    @root = { name: '0', title: '', inreplyto: nil }
    @thispage = nil
  end

  def tag_start(tag, attrs)
    case tag
    when 'text', 'freetext', 'annots', 'highlight'
      return if attrs.empty?
      @page = attrs['page'].to_i + @offset
      @name = attrs['name']
      @title = attrs['title']
      @date = attrs['date'].sub('D:', '').sub(/\+.*/, '').to_i
      @inreplyto = attrs['inreplyto']
      if attrs['rect']
        co = attrs['rect'].split(',').map {|a| a.to_i }
        @location = sprintf('%04d+%04d', 9999 - co[1], co[0]) # Y (swapped), X
      else
        @location = '0000+0000'
      end
    when 'contents', 'contents-richtext'
      @para = []
    when 'p'
      @inpara = true
    end
  end

  def text(s)
    @para << s.gsub("\r", "\n") if @inpara
  end

  def tag_end(tag)
    case tag
    when 'p'
      @para << "\n"
      @inpara = nil
    when 'contents', 'contents-richtext'
      @items << { name: @name, title: @title, inreplyto: @inreplyto, date: @date, page: @page, location: @location, contents: @para.join }
      @para = nil
    when 'xfdf'
      show_sorted_comments
    end
  end

  def show_sorted_comments
    map = {}

    @items.each do |e|
      map[e[:name]] = e
    end
    @tree = {}

    @items.sort_by {|x| x[:date]}.sort_by {|x| x[:location]}.sort_by {|x| x[:page]}.each do |e|
      # puts e
      pid = e[:inreplyto]
      if pid == nil || !map.has_key?(pid)
        (@tree[@root] ||= []) << e
      else
        (@tree[map[pid]] ||= []) << e
      end
    end

    print_tree(@root, 0)
  end

  def print_tree(item, level)
    items = @tree[item]
    unless items == nil
      items.each do |e|
        if @thispage != e[:page]
          @thispage = e[:page]
          puts "\n■ p.#{@thispage}"
        end
        if level < 1
          puts "\n■■ commented by #{e[:title]}"
        else
          puts "■■#{'■' * level} replied by #{e[:title]}"
        end
        puts e[:contents]
        print_tree(e, level + 1)
      end
    end
  end
end

def main
  offset = ENV['OFF'].nil? ? 1 : ENV['OFF'].to_i
  listener = XFDFListener.new(offset)
  source = ARGF
  Document.parse_stream(source, listener)
end
main
