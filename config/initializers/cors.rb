# Allow the Next.js frontend (Vercel or local) to call this API.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*(
      ENV.fetch("FRONTEND_ORIGINS", "http://localhost:3001")
        .split(",")
        .map(&:strip)
        .reject(&:empty?)
    ))

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization Content-Disposition],
      max_age: 600
  end
end
