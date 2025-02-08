#!/usr/bin/env ruby
# frozen_string_literal: true
require 'selenium-webdriver'

### CONSTANTS ###
# these are all relative to script file
TARGET_URL_FILE_NAME = 'target_url'
OUTPUT_URL_FILE_NAME = 'output_urls'
OUTPUT_CSV_FILE_NAME = 'results.csv'
OUTPUT_DECKLIST_DIR = 'decklists'

# defining xpath selectors as a constant because they don't (seem to) change
DECK_SELECTOR_XPATH = "//body/div[@id='js-reactroot']/main[@id='maincontent']/div[@class='container mb-5']/div[@class='browse-ad-layout']/div[@class='browse-ad-layout-content']/div[@class='row']/div[*]/div[*]/a[*]"
LOAD_MORE_BUTTON_XPATH = "//button[@class='btn xfXbvFpydldcPS0H45tv btn-secondary']//span[@class='YdEWqn292WqT4MUY5cvf']"
DOWNLOAD_DECKLIST_BUTTON_XPATH = "//span[contains(text(),'Download')]"
DECKLIST_TEXT_XPATH = "//textarea"
DECKLIST_NAME_XPATH = "//span[@class='deckheader-name']"

# time in seconds to click load more before timeing out
LOAD_MORE_DEPTH = 40

def sanitize_for_linux(input_str)
  return input_str.gsub(/\//, '\\').gsub(/\s+/, ' ').gsub(/ /, '\\ ')
end

# TODO: proper error handling
# TODO: handle decks having the same name
def gather_decklist_info
  url_file = File.open(TARGET_URL_FILE_NAME)
  target_url = url_file.read()
  url_file.close()


  logger = Selenium::WebDriver.logger
  logger.level = :debug

  driver =  Selenium::WebDriver.for :firefox
  driver.get target_url

  sleep 3

  begin
    while true do
      wait = Selenium::WebDriver::Wait.new(:timeout => LOAD_MORE_DEPTH)
      wait.until do
        load_more_button = driver.find_element(:xpath => LOAD_MORE_BUTTON_XPATH)
        load_more_button.click
      end
    end
  rescue Selenium::WebDriver::Error::TimeoutError
    print 'ran out'
  end

  deck_element_list = driver.find_elements(:xpath => DECK_SELECTOR_XPATH)
  output_url_list_file = File.open(OUTPUT_URL_FILE_NAME, 'w')

  deck_element_list.each do | element |
      output_url_list_file.write(element.attribute('href'))
      output_url_list_file.write("\n")
  end

  driver.quit

  output_url_list_file.close()
  output_url_list_file = File.open(OUTPUT_URL_FILE_NAME, 'r')

  output_csv_file = File.open(OUTPUT_CSV_FILE_NAME, 'w')
  output_csv_file.write("decklist_name#url\n")
  output_csv_file.close

  Dir.mkdir(OUTPUT_DECKLIST_DIR) unless File.directory?(OUTPUT_DECKLIST_DIR)

  output_csv_file = File.open(OUTPUT_CSV_FILE_NAME, 'a')

  url_list = output_url_list_file.read.split
  url_list.each do | url |
    driver = Selenium::WebDriver.for :firefox
    driver.get url
  
    wait = Selenium::WebDriver::Wait.new(timeout: LOAD_MORE_DEPTH, interval: 0.3)

    decklist_name_element = wait.until { driver.find_element(:xpath => DECKLIST_NAME_XPATH) }
    decklist_name = decklist_name_element.text
    sanitized_decklist_name = sanitize_for_linux(decklist_name)

    download_button = wait.until { driver.find_element(:xpath => DOWNLOAD_DECKLIST_BUTTON_XPATH) }
    download_button.click

    decklist_text_element = wait.until { driver.find_element(:xpath => DECKLIST_TEXT_XPATH) }
    decklist_text = decklist_text_element.text

    output_decklist_file_path = File.join(OUTPUT_DECKLIST_DIR, sanitized_decklist_name)
    output_decklist_file = File.open(output_decklist_file_path, 'w')

    output_decklist_file.write(decklist_text)
    output_csv_file.write("#{decklist_name}##{url}\n")

    driver.quit
  end

  output_csv_file.close
end

def main
  gather_decklist_info
end

main

