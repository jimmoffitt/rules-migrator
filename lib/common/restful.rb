class GnipRESTful
    require "net/https"     #HTTP gem.
    require "uri"

    attr_accessor :url, :uri, 
				  :user_name, 
				  :password, 
				  :headers, 
				  :data

    def initialize(url=nil, user_name=nil, password=nil, headers=nil)
	   @url = url if not url.nil?
	   @uri = URI.parse(@url) if not @url.nil?
	   
	   @user_name = user_name if not user_name.nil?
	   @password = password if not password.nil?
	   @headers = headers if not headers.nil?
    end

    def url=(value)
        @url = value
        @uri = URI.parse(@url)
    end

    #Fundamental REST API methods:
    def POST(url = nil, data = nil, headers = nil, parameters = nil)

  	    @data = data
		@url = url if not url.nil?
				
        uri = URI(@url)

		#params are passed in as a hash.
		#Example: params["max"] = 100, params["since_date"] = 20130321000000
		if not parameters.nil?
		   uri.query = URI.encode_www_form(parameters)
		end
				
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

		#TODO: port to DELETE method with new optional method parameter that does a POST
		if !parameters.nil? and parameters.key?("_method") 
			request = Net::HTTP::Post.new(uri.path + "?_method=delete")
		else
		   request = Net::HTTP::Post.new(uri.path)
		end

		#Add headers
		if not headers.nil?
			headers.each do |header|
		   		request[header[0]] = header[1]
			end
		end

        request.body = @data
        request.basic_auth(@user_name, @password)

        begin
            response = http.request(request)
        rescue
            sleep 5
			puts response
            response = http.request(request) #try again
        end

        return response
    end

    def PUT(url = nil, data = nil)

	   @data = data if not data.nil? #if request data passed in, use it.
	   @url = url if not url.nil?


        uri = URI(@url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Put.new(uri.path)
        request.body = @data
        request.basic_auth(@user_name, @password)

        begin
            response = http.request(request)
        rescue
            sleep 5
            response = http.request(request) #try again
        end

        return response
    end

    def GET(url = nil, params = nil)
	   
	    @url = url if not url.nil?
	   
        uri = URI(@url)

        #params are passed in as a hash.
        #Example: params["max"] = 100, params["since_date"] = 20130321000000
        if not params.nil?
            uri.query = URI.encode_www_form(params)
        end

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(@user_name, @password)

        begin
            response = http.request(request)
        rescue
            sleep 5
            response = http.request(request) #try again
        end

        return response
    end

    def DELETE(url = nil, data = nil)
        if not data.nil?
            @data = data
        end

        uri = URI(@url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Delete.new(uri.path)
        request.body = @data
        request.basic_auth(@user_name, @password)

        begin
            response = http.request(request)
        rescue
            sleep 5
            response = http.request(request) #try again
        end

        return response
    end
end #PtREST class.

