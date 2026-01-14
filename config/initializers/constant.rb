
BACKEND_HOST = ENV.fetch('BACKEND_HOST', 'https://app.vinylsaigon.vn')
FRONTEND_HOST = ENV.fetch('FRONTEND_HOST', 'https://vinylsaigon.vn')

STORE_CONFIG = {
  name: 'Vinyl Sài Gòn',
  domain: 'vinylsaigon.vn',
  noreply_email: 'noreply@vinylsaigon.vn',
  support_email: 'support@vinylsaigon.vn',
  phone_number: '0914 345 357',
  instagram_url: 'https://www.instagram.com/vinylsaigon',
  youtube_url: 'https://www.youtube.com/@vinylsaigon4576',
  facebook_url: 'https://www.facebook.com/VinylSaiGon',
  tiktok_url: nil,
  shopee_url: nil
}.freeze

JWT_SECRET_KEY = ENV.fetch('JWT_SECRET_KEY', 'jwt_secret_key')

MEILISEARCH_HOST = ENV.fetch('MEILISEARCH_HOST', 'http://localhost:7700')

DEFAULT_CATEGORIES = [
  {
    name: 'Tai nghe',
    description: 'Tai nghe cao cấp cho âm thanh tuyệt vời.',
    image: 'headphone.jpg',
    button_text: 'Xem thêm',
    children: [
      { name: 'Over-Ear' },
      { name: 'On-Ear' },
      { name: 'In-Ear' },
      { name: 'Earbud' },
      { name: 'Không dây' },
    ]
  },
  {
    name: 'DAC/AMP',
    slug: 'dac-amp',
    description: 'Tăng cường chất lượng âm thanh với DAC/AMP.',
    image: 'dac-amp.jpg',
    button_text: 'Xem thêm',
    children: [
      { name: 'Portable DAC/AMP' },
      { name: 'Desktop DAC/AMP' },
      { name: 'Speaker Amplifier' },
      { name: 'Bluetooth DAC/AMP' },
      { name: 'Phono stage' },
    ]
  },
  {
    name: 'Loa',
    description: 'Loa và hệ thống âm thanh cao cấp.',
    image: 'speaker.jpg',
    button_text: 'Xem thêm',
    children: [
      { name: 'Loa Bookshelf' },
      { name: 'Loa Di Động' },
      { name: 'Loa Hi-Fi' },
      { name: 'Loa Subwoofer' },
      { name: 'Soundbar' },
    ]
  },
  {
    name: 'Nguồn phát',
    description: 'Nguồn phát audio, vinyl, CD chất lượng cao.',
    image: 'audio-source.jpg',
    button_text: 'Xem thêm',
    children: [
      { name: 'Máy nghe nhạc' },
      { name: 'Máy cát sét' },
      { name: 'Máy nghe CD' },
      { name: 'Mâm đĩa than' },
    ]
  },
  {
    name: 'Home Studio',
    description: 'Thiết bị chuyên nghiệp cho home studio.',
    image: 'home-studio.jpg',
    button_text: 'Xem thêm',
    children: [
      { name: 'Microphone' },
      { name: 'Soundcard' },
      { name: 'Camera' },
      { name: 'Thiết bị khác' },
    ]
  },
  {
    name: 'Phụ kiện',
    description: 'Phụ kiện âm thanh chất lượng cao.',
    image: 'accessories.jpg',
    button_text: 'Xem thêm',
    children: [
      { name: 'Dây Tai nghe' },
      { name: 'Dây USB-OTG' },
      { name: 'Hộp đựng' },
      { name: 'Kim đĩa than' },
      { name: 'Eartip/Earpad' },
      { name: 'Phụ kiện khác' },
    ]
  },
].freeze

# Realistic category relationships based on audio equipment compatibility
# Format: { category_name => [{ related_category: 'name', weight: number }] }
CATEGORY_RELATIONSHIPS = {
  # Headphones are most related to DAC/AMP for driving power
  'Tai nghe' => [
    { related_category: 'DAC/AMP', weight: 8 },
    { related_category: 'Phụ kiện', weight: 6 }, # cables, cases
    { related_category: 'Nguồn phát', weight: 4 },  # music players
  ],

  # DAC/AMP strongly relates to headphones and speakers
  'DAC/AMP' => [
    { related_category: 'Tai nghe', weight: 8 },
    { related_category: 'Loa', weight: 7 },
    { related_category: 'Nguồn phát', weight: 6 },
    { related_category: 'Phụ kiện', weight: 5 },
  ],

  # Speakers relate to amplifiers and sources
  'Loa' => [
    { related_category: 'DAC/AMP', weight: 7 },
    { related_category: 'Nguồn phát', weight: 6 },
    { related_category: 'Home Studio', weight: 5 },
    { related_category: 'Phụ kiện', weight: 4 },
  ],

  # Sources relate to output devices and amplifiers
  'Nguồn phát' => [
    { related_category: 'DAC/AMP', weight: 6 },
    { related_category: 'Tai nghe', weight: 4 },
    { related_category: 'Loa', weight: 6 },
    { related_category: 'Phụ kiện', weight: 7 }, # cables, needles
  ],

  # Home Studio relates to recording and monitoring equipment
  'Home Studio' => [
    { related_category: 'Tai nghe', weight: 7 }, # monitoring headphones
    { related_category: 'Loa', weight: 6 },      # studio monitors
    { related_category: 'DAC/AMP', weight: 5 },
    { related_category: 'Phụ kiện', weight: 8 },  # cables, stands, etc
  ],

  # Accessories complement all other categories
  'Phụ kiện' => [
    { related_category: 'Tai nghe', weight: 6 },
    { related_category: 'DAC/AMP', weight: 5 },
    { related_category: 'Nguồn phát', weight: 7 }, # turntable needles, etc
    { related_category: 'Home Studio', weight: 8 },
  ],

  # Child category specific relationships (higher weights for more specific compatibility)
  'Over-Ear' => [
    { related_category: 'Desktop DAC/AMP', weight: 9 }, # need more power
    { related_category: 'Dây Tai nghe', weight: 8 },
  ],

  'In-Ear' => [
    { related_category: 'Portable DAC/AMP', weight: 10 }, # perfect match
    { related_category: 'Máy nghe nhạc', weight: 8 },
    { related_category: 'Dây Tai nghe', weight: 7 },
  ],

  'Không dây' => [
    { related_category: 'Bluetooth DAC/AMP', weight: 9 },
    { related_category: 'Máy nghe nhạc', weight: 6 },
  ],

  'Portable DAC/AMP' => [
    { related_category: 'In-Ear', weight: 10 },
    { related_category: 'On-Ear', weight: 8 },
    { related_category: 'Máy nghe nhạc', weight: 7 },
  ],

  'Desktop DAC/AMP' => [
    { related_category: 'Over-Ear', weight: 9 },
    { related_category: 'Loa Bookshelf', weight: 8 },
    { related_category: 'Mâm đĩa than', weight: 7 },
  ],

  'Bluetooth DAC/AMP' => [
    { related_category: 'Không dây', weight: 9 },
    { related_category: 'Loa Di Động', weight: 7 },
  ],

  'Loa Bookshelf' => [
    { related_category: 'Desktop DAC/AMP', weight: 8 },
    { related_category: 'Speaker Amplifier', weight: 9 },
    { related_category: 'Mâm đĩa than', weight: 6 },
  ],

  'Loa Di Động' => [
    { related_category: 'Bluetooth DAC/AMP', weight: 7 },
    { related_category: 'Máy nghe nhạc', weight: 6 },
  ],

  'Mâm đĩa than' => [
    { related_category: 'Phono stage', weight: 10 }, # essential
    { related_category: 'Desktop DAC/AMP', weight: 8 },
    { related_category: 'Kim đĩa than', weight: 9 },
    { related_category: 'Over-Ear', weight: 6 },
  ],

  'Phono stage' => [
    { related_category: 'Mâm đĩa than', weight: 10 },
  ],

  'Microphone' => [
    { related_category: 'Soundcard', weight: 9 },
    { related_category: 'Tai nghe', weight: 7 }, # monitoring
  ],

  'Soundcard' => [
    { related_category: 'Microphone', weight: 9 },
    { related_category: 'Tai nghe', weight: 8 },
    { related_category: 'Loa', weight: 6 },
  ],

  'Eartip/Earpad' => [
    { related_category: 'In-Ear', weight: 10 },
    { related_category: 'Over-Ear', weight: 9 },
    { related_category: 'On-Ear', weight: 9 },
    { related_category: 'Tai nghe', weight: 8 },
  ]
}.freeze

SESSION_EXPIRES_IN_DAYS = 30

HERO_BANNER_DEFAULT_TEXT_COLOR = '#ffffff'
