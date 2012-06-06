#!/usr/bin/ruby
# Lazy text converter for Acrobat XFDF (note dump)
# Copyright (c) 2012 Kenshi Muto <kmuto@debian.org>.
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
    @page = 1
    @offset = offset
    @para = nil
    @beginning = true
  end

  def tag_start(tag, attrs)
    case tag
    when "text", "freetext", "annots"
      @page = attrs["page"].to_i
      if @beginning.nil?
        puts
      else
        @beginning = nil
      end
      puts "[p.#{@page + @offset}]"
    when "p", "contents"
      @para = ""
    end
  end

  def text(s)
    @para << s unless @para.nil?
  end

  def tag_end(tag)
    case tag
    when "p", "contents"
      puts @para.gsub("\r", "\n")
      @para = nil
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
