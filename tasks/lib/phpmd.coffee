###
grunt-phpmd

Copyright (c) 2013 Andreas Lappe
http://kaeufli.ch
Licensed under the BSD license.
###

path = require 'path'
color = require 'color'
exec = (require 'child_process').exec
{parseString} = require 'xml2js'
Table = require 'cli-table2'

exports.init = (grunt) ->

  exports = config = {}
  cmd = done = null
  defaults =
    bin: 'phpmd'
    # Can be xml, text or html
    reportFormat: 'xml'
    # Path and filename, otherwise STDOUT is used
    reportFile: false
    suffixes: false
    exclude: false
    minimumPriority: false
    strict: false
    rulesets: 'codesize,unusedcode,naming'
    maxBuffer: 200*1024
    ignoreErrorCode: false
    ignoreWarningCode: true
    failOnError: false
    failOnWarning: false
    errorTreshold: 3
    warningTreshold: 2
    xml2cli: false

  buildCommand = (dir) ->
    cmd = "#{path.normalize config.bin} #{dir} #{config.reportFormat} #{config.rulesets}"
    cmd += " --minimumpriority #{config.minimumPriority}" if config.minimumPriority
    cmd += " --reportfile #{config.reportFile}" if config.reportFile
    cmd += " --suffixes #{config.suffixes}" if config.suffixes
    cmd += " --exclude #{config.exclude}" if config.exclude
    cmd += " --strict" if config.strict
    cmd

  exports.setup = (runner) ->
    dir = path.normalize runner.data.dir
    config = runner.options defaults
    if config.reportFormat == 'cli'
      config.reportFormat = 'xml'
      config.xml2cli = true
    cmd = buildCommand dir
    grunt.log.writeln "Starting phpmd (target: #{runner.target.cyan}) in #{dir.cyan}"
    grunt.verbose.writeln "Execute: #{cmd}"
    done = runner.async()

  exports.run = ->
    cmdOptions = maxBuffer: config.maxBuffer
    exec cmd, cmdOptions, (err, stdout, stderr) ->

      # CLI output
      if config.reportFormat == 'xml' && config.xml2cli

        # parse xml
        xml = stdout.replace(/^Warning.*$/gm, '')

        # counter variables
        errors = 0
        warnings = 0
        infos = 0

        # parse xml
        parseString xml, (err, result) ->

          # have output?
          if result.pmd['file'] && result.pmd['file'].length
            # parse all errored files
            for file in result.pmd['file']
              # table data
              table = new Table({
                chars: { 'top': '' , 'top-mid': '' , 'top-left': '' , 'top-right': ''
                       , 'bottom': '' , 'bottom-mid': '' , 'bottom-left': '' , 'bottom-right': ''
                       , 'left': '' , 'left-mid': '' , 'mid': '' , 'mid-mid': ''
                       , 'right': '' , 'right-mid': '' , 'middle': ' ' },
                style: { 'padding-left': 0, 'padding-right': 0 }
              });

              # get filename
              filename = file.$.name.replace(process.cwd(), "")

              # loop through violations
              for violation in file.violation

                # categorize violation and count
                if violation.$.priority >= config.errorTreshold
                  level = "✖".red
                  errors++
                else if violation.$.priority >= config.warningTreshold
                  level = "⚠".bold.yellow
                  warnings++
                else
                  level = "ℹ".blue
                  infos++

                # output current violation
                #grunt.log.writeln("  "+ level + "  " + filename + ":" + violation.$.beginline+ ": "+ violation._.replace(/(\r\n|\n|\r)/gm,"").bold + " " + (violation.$.ruleset+ "/"+ violation.$.rule).grey)
                table.push(["  "+ level + "  " + filename + ":" + violation.$.beginline, violation._.replace(/(\r\n|\n|\r)/gm,"").bold, (violation.$.ruleset+ "/"+ violation.$.rule).grey])


            console.log(table.toString());

            # new line
            grunt.log.writeln("");

            # summary
            grunt.log.write("Summary: ".bold+result.pmd['file'].length + " file(s) with ");
            if (errors > 0)
              grunt.log.write((errors + " error(s) ").red)
            if (warnings > 0)
              grunt.log.write((warnings + " warning(s) ").yellow)
            if (infos > 0)
              grunt.log.write((infos + " info(s) ").blue)
            if (errors +  warnings + infos == 0)
              grunt.log.write(" no errors, warnings or infos".green)

            # newline
            grunt.log.writeln("");

            # fail if wanted so
            if ((config.failOnError && errors > 0) || (config.failOnWarning && warnings > 0 ) )
              done( false )

            # just end without erros/warnings
            else
              grunt.log.writeln("No errors, warnings".green)
              done()

          # not output, no errors, done
          else
            grunt.log.writeln("No errors, warnings or infos".green)
            done()
      else
        grunt.log.write stdout if stdout

        # As documented on # http://phpmd.org/documentation/index.html#exit-codes
        grunt.fatal stdout if err and err.code is 1 and config.ignoreErrorCode is false
        grunt.warn stdout if err and err.code is 2 and config.ignoreWarningCode is false

        done()


  exports
