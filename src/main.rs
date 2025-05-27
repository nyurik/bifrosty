use std::error::Error;

use clap::{Parser, Subcommand};
use log::{error, log_enabled};

#[derive(Parser, Debug, PartialEq)]
#[command(
    version,
    about = "A tool to make Valhalla happier",
    after_help = "Use RUST_LOG environment variable to control logging level, e.g. RUST_LOG=debug or RUST_LOG=bifrosty=debug. See https://docs.rs/env_logger/latest/env_logger/index.html#enabling-logging for more information."
)]
pub struct Args {
    /// Enable verbose output
    #[arg(short, long)]
    verbose: bool,
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, PartialEq, Debug)]
enum Commands {
    /// Some help text about the test
    Test,
}

fn main() {
    let env = env_logger::Env::default().default_filter_or("bifrosty=info");
    env_logger::Builder::from_env(env).init();

    if let Err(e) = start(Args::parse()) {
        // Ensure the message is printed, even if the logging is disabled
        if log_enabled!(log::Level::Error) {
            error!("{e}");
        } else {
            eprintln!("{e}");
        }
        std::process::exit(1);
    }
}

fn start(args: Args) -> Result<(), Box<dyn Error>> {
    match args.command {
        Commands::Test => {
            println!("Running test command...");
        }
    }
    Ok(())
}
