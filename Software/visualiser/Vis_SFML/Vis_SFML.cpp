// Vis_SFML.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <SFML/Graphics.hpp>
#include <fstream>
#include <string>
#include <algorithm>
#include <math.h>
#include <array>
#include <chrono>

constexpr int GRIDX = 64;
constexpr int GRIDY = 64;

constexpr int SQ_WIDTH = 15;
constexpr int SQ_HEIGHT = 15;

constexpr int VIEW_WIDTH = SQ_WIDTH * GRIDX;
constexpr int VIEW_HEIGHT = SQ_HEIGHT * GRIDY;

constexpr int NUM_VIEWS = 2;
constexpr int NUM_MOVIES = 2;
constexpr size_t MOVIE_LENGTH = 1024;
constexpr size_t TIME_PER_FRAME = 20; //milliseconds

constexpr int SCREEN_WIDTH = VIEW_WIDTH * NUM_VIEWS;
constexpr int SCREEN_HEIGHT = VIEW_HEIGHT;

const std::string path = "C:\\Users\\Jonah\\Documents\\Projects\\ScienceFair\\Software\\data";

//hsv to rgb
// hue: 0-360°; sat: 0.f-1.f; val: 0.f-1.f
sf::Color hsv(int hue, float sat, float val) {
    hue %= 360;
    while(hue<0) hue += 360;

    if(sat<0.f) sat = 0.f;
    if(sat>1.f) sat = 1.f;

    if(val<0.f) val = 0.f;
    if(val>1.f) val = 1.f;

    int h = hue/60;
    float f = float(hue)/60-h;
    float p = val*(1.f-sat);
    float q = val*(1.f-sat*f);
    float t = val*(1.f-sat*(1-f));

    switch(h) {
        default:
        case 0:
        case 6: return sf::Color(val*255, t*255, p*255);
        case 1: return sf::Color(q*255, val*255, p*255);
        case 2: return sf::Color(p*255, val*255, t*255);
        case 3: return sf::Color(p*255, q*255, val*255);
        case 4: return sf::Color(t*255, p*255, val*255);
        case 5: return sf::Color(val*255, p*255, q*255);
    }
}

sf::Color heat(int min, int max, int val) {
    float ratio = 2 * (val - min) / float(max - min);
    int b = int(std::max(0.f, 255 * (1 - ratio)));
    int r = int(std::max(0.f, 255 * (ratio - 1)));
    int g = 255 - b - r;
    return sf::Color(r, g, b);

}

std::pair<long long, long long> getMinMax(std::string filename, bool is_movie = false) {
    std::ifstream file;
    long long min = std::numeric_limits<long long>::max();
    long long max = std::numeric_limits<long long>::min();
    for (int i = 0; i < (is_movie ? MOVIE_LENGTH : 1); i++) {
        file.open(path + "\\" + filename + (is_movie ? std::to_string(i) : "") + ".txt");
        //skip first three lines
        file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        //on second pass, normalise and draw
        while (!file.eof()) {
            std::string val;
            std::getline(file, val, ',');
            long long value = std::stoll(val);
            min = std::min(min, value);
            max = std::max(max, value);
        }
        file.close();
    }
    return std::make_pair(min, max);
}

void visualiseFile(sf::Uint8* pixels, std::ifstream& file, std::pair<long long, long long> minmax) {
    //skip first three lines
    file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    file.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    //on second pass, normalise and draw
    int y = 0;
    int x = 0;
    while (!file.eof()) {
        std::string val;
        std::getline(file, val, ',');
        long long value = std::stoll(val);
        //std::cout << value << std::endl;
        //we want to normalise the value to be between 0 and 1
        float normalised = (value - minmax.first) / float(minmax.second - minmax.first);
        sf::Color colour = hsv(270 - 270 * sqrt(normalised), sqrt(normalised), 1);
        //sf::Color colour = heat(0, max, value);
        //set all pixels in the square around x, y to colour
        for (int i = 0; i < SQ_HEIGHT; i++) {
            for (int j = 0; j < SQ_WIDTH; j++) {
                int index = ((y * SQ_HEIGHT + i) * VIEW_WIDTH + x * SQ_WIDTH + j) * 4;
                pixels[index] = colour.r;
                pixels[index + 1] = colour.g;
                pixels[index + 2] = colour.b;
                pixels[index + 3] = 255;

            }
        }

        x = (x + 1) % GRIDX;
        if (x == 0) y++;

    }
}

void renderSprite(sf::Texture& texture, std::ifstream& file, std::pair<long long, long long> minmax) {
    sf::Uint8* pixels = new sf::Uint8[VIEW_WIDTH * VIEW_HEIGHT * 4];
    visualiseFile(pixels, file, minmax);
    texture.create(VIEW_WIDTH, VIEW_HEIGHT);
    texture.update(pixels);
    delete [] pixels;
}

int main()
{
    sf::RenderWindow* window = new sf::RenderWindow(sf::VideoMode(SCREEN_WIDTH, SCREEN_HEIGHT), "FuSim Visualiser", sf::Style::Default);

    sf::View* views = new sf::View[NUM_VIEWS];
    std::array<bool, NUM_VIEWS> is_movie = { true, true };
    std::string* filenames = new std::string[NUM_VIEWS]{"rho", "phi"};
    std::ifstream* files = new std::ifstream[NUM_VIEWS];
    sf::Texture* textures = new sf::Texture[NUM_VIEWS];
    sf::Sprite* sprites = new sf::Sprite[NUM_VIEWS];
    std::array<std::pair<long long, long long>, NUM_VIEWS> minmax;
    for (int i = 0; i < NUM_VIEWS; i++) {
        minmax[i] = getMinMax(filenames[i], is_movie[i]);
    }

    bool paused = true;
    size_t frame = 0;
    for (int i = 0; i < NUM_VIEWS; i++) {
        views[i] = sf::View(sf::FloatRect(0, 0, VIEW_WIDTH, VIEW_HEIGHT));
        views[i].setViewport(sf::FloatRect(float(i) / NUM_VIEWS, 0, 1.f / NUM_VIEWS, 1));
        std::string filename;
        if (is_movie[i]) {
            filename = filenames[i] + std::to_string(frame)  + ".txt";
        } else {
            filename = filenames[i] + ".txt";
        }
        files[i].open(path + "\\" + filename);
        if (!files[i].is_open()) {
            std::cout << "Could not open file " << filename << std::endl;
            return 1;
        }
        renderSprite(textures[i], files[i], minmax[i]);
        sprites[i].setTexture(textures[i]);
    }

    std::chrono::steady_clock::time_point last_time = std::chrono::steady_clock::now();
    std::chrono::steady_clock::time_point current_time;

    while (window->isOpen()) {
        sf::Event event;
        while (window->pollEvent(event)) {
            if (event.type == sf::Event::Closed || sf::Keyboard::isKeyPressed(sf::Keyboard::Escape))
                window->close();
            if (event.type == sf::Event::KeyPressed) {
                if (event.key.code == sf::Keyboard::Right || event.key.code == sf::Keyboard::Left) {
                    paused = true;
                    for (int i = 0; i < NUM_MOVIES; i++) {
                        frame = event.key.code == sf::Keyboard::Right ? frame + 1 : frame == 0 ? MOVIE_LENGTH - 1 : frame - 1;
                        if (frame >= MOVIE_LENGTH) frame = 0;
                    }
                    for (int i = 0; i < NUM_VIEWS; i++) {
                        if (is_movie[i]) {
                            files[i].close();
                            files[i].open(path + "\\" + filenames[i] + std::to_string(frame) + ".txt");
                            renderSprite(textures[i], files[i], minmax[i]);
                            sprites[i].setTexture(textures[i]);
                        }
                    }
                }
                else if (event.key.code == sf::Keyboard::Space || event.key.code == sf::Keyboard::P) {
                    paused = !paused;
                }
                else if (event.key.code == sf::Keyboard::R) {
                    frame = 0;
                    for (int i = 0; i < NUM_VIEWS; i++) {
                        if (is_movie[i]) {
                            files[i].close();
                            files[i].open(path + "\\" + filenames[i] + std::to_string(frame) + ".txt");
                            renderSprite(textures[i], files[i], minmax[i]);
                            sprites[i].setTexture(textures[i]);
                        }
                    }
                }
            }

        }
         
        window->clear();
        current_time = std::chrono::steady_clock::now();
        if (!paused && std::chrono::duration_cast<std::chrono::milliseconds>(current_time - last_time).count() >= TIME_PER_FRAME) {
            frame = (frame + 1) % MOVIE_LENGTH;
            for (int i = 0; i < NUM_VIEWS; i++) {
                if (is_movie[i]) {
                    files[i].close();
                    files[i].open(path + "\\" + filenames[i] + std::to_string(frame) + ".txt");
                    renderSprite(textures[i], files[i], minmax[i]);
                    sprites[i].setTexture(textures[i]);
                }
            }
            last_time = current_time;
        }
        for (int i = 0; i < NUM_VIEWS; i++) {
            window->setView(views[i]);
            window->draw(sprites[i]);
            //draw line on boundary
            sf::RectangleShape line(sf::Vector2f(1, VIEW_HEIGHT));
            line.setFillColor(sf::Color::Black);
            line.setPosition(VIEW_WIDTH - 1, 0);
            window->draw(line);
        }

        window->display();
    }
    
    return 0;
}
