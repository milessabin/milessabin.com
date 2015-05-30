#global module:false

path = require 'path'

"use strict"

module.exports = (grunt) ->
  minify = grunt.option('minify') ? false

  grunt.loadNpmTasks "grunt-contrib-connect"
  grunt.loadNpmTasks "grunt-contrib-copy"
  grunt.loadNpmTasks "grunt-contrib-less"
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-exec"
  grunt.loadNpmTasks "grunt-webfont"

  grunt.initConfig
    less:
      screen:
        options:
          paths: [
            "node_modules"
            "src/css"
          ]
          compress: minify
          yuicompress: minify
        files:
          "target/css/screen.css" : "src/css/screen.less"
          "target/css/print.css"  : "src/css/print.less"
          "target/css/ie8.css"    : "src/css/ie8.less"
          "target/css/ie9.css"    : "src/css/ie9.less"
          "target/css/ie10.css"   : "src/css/ie10.less"

    webfont:
      icons:
        src: "src/icons/*.svg"
        dest: "target/fonts"
        destCss: "src/css/common/icons"
        options:
          font: 'ms'
          engine: 'node'
          htmlDemo: false
          relativeFontPath: '/fonts/'
          syntax: 'bootstrap'
          rename: (filename) -> 'ms-' + path.basename(filename)

    copy:
      images:
        files: [{
          expand: true
          cwd: "src/images"
          src: ["**"]
          dest: "target/images/"
        }]
      js:
        files: [{
          expand: true
          cwd: "src/js"
          src: ["**"]
          dest: "target/js/"
        }]

    exec:
      install:
        cmd: "bundle install"
      jekyllLocal:
        cmd: "bundle exec jekyll build --drafts --trace --config jekyll_config.yml"
      jekyllLive:
        cmd: "bundle exec jekyll build --trace --config jekyll_config.yml"
      deploy:
        cmd: 'rsync --progress -a --delete --exclude files -e "ssh -q" target/ dreamhost:milessabin.com'

    watchImpl:
      options:
        livereload: true
      css:
        files: [
          "src/icons/**/*"
          "src/css/**/*"
        ]
        tasks: [
          "webfont"
          "less"
          "exec:jekyllLocal"
        ]
      js:
        files: [
          "src/js/**/*"
        ]
        tasks: [
          "copy"
          "exec:jekyllLocal"
        ]
      images:
        files: [
          "src/images/**/*"
        ]
        tasks: [
          "copy"
          "exec:jekyllLocal"
        ]
      html:
        files: [
          "src/html/**/*"
          "jekyll_plugins/**/*"
          "jekyll_config.yml"
        ]
        tasks: [
          "copy"
          "exec:jekyllLocal"
        ]

    connect:
      server:
        options:
          port: 4000
          base: 'target'

  grunt.renameTask "watch", "watchImpl"

  grunt.registerTask "build:base", [
    # "webfont"
    "less"
    "copy"
  ]

  grunt.registerTask "build", [
    "build:base"
    "exec:jekyllLocal"
  ]

  grunt.registerTask "serve", [
    "build"
    "connect:server"
    "watchImpl"
  ]

  grunt.registerTask "deploy", [
    "build:base"
    "exec:jekyllLive"
    "exec:deploy"
  ]

  grunt.registerTask "watch", [
    "serve"
  ]

  grunt.registerTask "default", [
    "build"
  ]
