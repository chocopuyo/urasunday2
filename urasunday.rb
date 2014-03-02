require 'open-uri'
require 'nokogiri'
require 'rss/maker'
require './rss_cdata'

#urlからparseしたdocを取得するメソッド
def get_doc(url)
  charset = nil
  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  # htmlをパース(解析)してオブジェクトを生成
  doc = Nokogiri::HTML.parse(html, nil, charset)
end

#トップページを取得
url = 'http://urasunday.com'
root = get_doc(url)

#ここからギコギコする(｀・ω・´) 
#topページから連載マンガのURL一覧を取得
manga_urls = []
mangas = root.css(".indexComicDetailWrapper")#.attribute("href").value
mangas.each do |manga|
  #連載日の画像を取得する
  rensai_img = manga.css(".indexComicDetailOD03 img").attribute("src").value
  #もし連載日の画像が完結済だったらそのマンガは取得しない
  unless rensai_img == "./images/index_list_cmp_s.png"
    manga_urls << url +"/"+ manga.css(".indexComicDetailOD01 a").attribute("href").value
  end
end
##テスト用
#puts manga_urls = ["http://urasunday.com/./mobupsycho100/index.html"]
#各マンガの掲載情報を取得
episode_urls = []
manga_urls.each do |manga_url|
  doc = get_doc(manga_url)
  #掲載されている話を取得(aタグが付いているものだけが読める)
  episodes = doc.css(".comicsCoverBox2 a")#.attribute("href").value
  episodes.each do |episode|
    episode_urls << manga_url.sub("index.html","")+episode.attribute("href").value if episode.attribute("class").nil?
  end
end

#各掲載エピソードの情報を取得
episodes = []
episode_urls.each_with_index do |episode_url,index|
  episode_num_and_volume = episode_url.match(/[0-9]+_[0-9]+/).to_s
  episode = get_doc(episode_url)
  comic_detail = episode.css("#comicDetail")
  info = comic_detail.css(".comicTitleDate").inner_text
  #文字コード周りがカオス
  info.encode!("iso-8859-1","utf-8")
  sep =  "\xEF\xBD\x9C".force_encoding("iso-8859-1")
  episode_num = info.split(sep)[0].force_encoding("utf-8")
  episode_num_i = episode_num.match(/\d+/)[0].to_i
  #日付
  date = info.split(sep)[1].force_encoding("utf-8").sub("更新","").split("/")
  date = Date::new(date[0].to_i, date[1].to_i, date[2].to_i)
  #タイトル
  title = comic_detail.css("h1").inner_text.encode("iso-8859-1","utf-8").force_encoding("utf-8")+episode_num
  #著者
  author  = comic_detail.css("h2").inner_text.encode("iso-8859-1","utf-8").force_encoding("utf-8")
  #画像を取得
  #imgurlのための英字タイトル取得
  title_eng = episode_url.match(/\.\/[a-z0-9]+\//)[0].match(/[a-z0-9]+/)[0]
  images = ""
  num = 1
  while(true) do
    begin
      num += 1
      url = "http://img.urasunday.com/eximages/comic/#{title_eng}/pc/#{sprintf('%03d', episode_num_i)}/#{episode_num_and_volume}_#{sprintf('%02d', num)}.jpg"
      open url do |f|
        images += "<img src='#{url}' /><br />" if f.status[0] == "200"
      end
    rescue
      break
    end
  end
  episodes << {"date"=>date,"title"=>title,"author"=>author,"link"=>episode_url,"description"=>images}
end

#rss作成
rss = RSS::Maker.make("1.0") do |rss|
  rss.channel.about = 'http://chocopuyo.com/rss.xml'
  rss.channel.title = "裏サンデー"
  rss.channel.description = "裏サンデーの非公式rssです"
  rss.channel.link = 'http://urasunday.com'
  rss.channel.language = "ja"
  
  rss.items.do_sort = true

  episodes.each do |episode|
    item = rss.items.new_item
    item.title = episode['title']
    item.link = episode['link']
    item.description = episode['title'] 
    item.date = episode['date'].to_s
    item.author =  episode['author']
    item.content_encoded = episode['description']
  end.to_s
end

# ファイルに書き出し
output_file = File.open("urasunday.rdf", "w")    # 書き込み専用でファイルを開く（新規作成）
output_file.write(rss)    # ファイルにデータ書き込み
output_file.close # ファイルクローズ
#エンコード方法
#puts manga.encode("iso-8859-1")
