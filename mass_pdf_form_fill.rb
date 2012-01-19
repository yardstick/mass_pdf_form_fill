$: << File.expand_path(File.join(File.dirname(__FILE__), 'vendor'))

require 'bundler/setup'
require 'java'
require 'itextpdf-5.1.3.jar'
require 'yajl'
require 'tempfile'
require 'ruby-debug'

EmptyString = ''

input_filename, output_filename = ARGV.take(2)

abort('No input template specified') if input_filename.nil?

def with_copy(filename = nil)
  output = filename.nil? ? java.io.BufferedOutputStream.new(java.lang.System.out) : java.io.FileOutputStream.new(filename)
  copy = com.itextpdf.text.pdf.PdfCopyFields.new(output)
  copy.open
  yield(copy)
rescue => boom
  warn(boom.message)
  warn(boom.backtrace.join("\n"))
ensure
  copy.close
end

def with_reader(input)
  yield(com.itextpdf.text.pdf.PdfReader.new(input))
end

def with_byte_array_output_stream
  yield(java.io.ByteArrayOutputStream.new)
end

def with_stamper(reader, output)
  stamper = com.itextpdf.text.pdf.PdfStamper.new(reader, output)
  form = stamper.get_acro_fields
  @field_names ||= form.get_fields.keys
  yield(stamper, form, @field_names)
  stamper.set_form_flattening(true)
ensure
  stamper.close if stamper.respond_to?(:close)
end

def copy_reader(reader)
  com.itextpdf.text.pdf.PdfReader.new(reader)
end

with_copy(output_filename) do |copy|
  with_reader(input_filename) do |reader|
    Yajl::Parser.parse(STDIN) do |variables|
      with_byte_array_output_stream do |output|
        with_stamper(copy_reader(reader), output) do |stamper, form, field_names|
          field_names.each do |field|
            form.set_field(field, variables.fetch(field, EmptyString))
          end
        end

        with_reader(output.to_byte_array) do |stamped_reader|
          copy.add_document(stamped_reader)
        end
      end
    end
  end
end
