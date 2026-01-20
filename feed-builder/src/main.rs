use clap::Parser;
use std::{
    fs::{self, File, read_dir},
    io::{self, Read, Write},
    path::{Path, PathBuf},
};

#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Cli {
    /// Path to the directory with html files
    #[arg(short, long)]
    html_dir: PathBuf,
    /// Base URL of the site to be used for links in the resulting feed
    #[arg(short, long)]
    base_url: String,
    /// Title of the feed
    #[arg(short, long)]
    title: String,
}

use rss::{ChannelBuilder, Item};
fn main() -> io::Result<()> {
    simple_logger::init_with_level(log::Level::Info).unwrap();
    let cli = Cli::parse();
    log::info!("directory is {}", cli.html_dir.display());

    let mut channel = ChannelBuilder::default()
        .title(&cli.title)
        .link(&cli.base_url)
        .description("RSS feed of ".to_owned() + &cli.title)
        .build();

    let files = read_dir(cli.html_dir)?;
    for file in files {
        let file_path = file?.path();
        if let Some(ext) = file_path.extension()
            && ext == "html"
        {
            log::info!("processing file {}", file_path.display());
            let mut item: Item = Item::default();
            let mut buf = String::new();
            File::open(&file_path)
                .unwrap()
                .read_to_string(&mut buf)
                .unwrap();
            if let Some((title, _)) = buf
                .as_str()
                .split_once("<title>")
                .and_then(|(_, suffix)| suffix.split_once("</title>"))
            {
                log::info!("title: {:?}", title);
                item.set_title(Some(title.to_string()));
                item.set_description(Some(buf));
                item.set_link(Some(
                    Path::new(&cli.base_url)
                        .join(file_path)
                        .to_string_lossy()
                        .to_string(),
                ));
                channel.items.push(item);
            } else {
                log::warn!("title not found in {:?}", &file_path.display());
            }
        }
    }

    channel.write_to(::std::io::sink()).unwrap(); // // write to the channel to a writer
    let string = channel.to_string(); // convert the channel to a string

    let mut file = fs::File::create("feed.xml").unwrap();
    file.write_all(string.as_bytes()).unwrap();
    Ok(())
}
