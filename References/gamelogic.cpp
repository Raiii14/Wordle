#include<iostream>
char frequencyMap[26] = {};

char* getGuess() {
  char* output;
  return output;
}
void populateFrequencyMap(char* word) {
  for (int i = 0; i < 5; i++) {
    frequencyMap[word[i]-'a']++;
  }
}
void clearFrequencyMap() {
//prolly best if xor nlng
  for (int i = 0; i < 26; i++) {
    frequencyMap[i]==0;
  }
}
char* getRandomWord() {
  char* output;
  return output;
}
bool is_in_string(const char& letter) {
  return true;
}
bool is_in_position(const char& letter) {
  return true;
}
void colorBoxes(int color[]) {
  
}

void gamelogic() {
  int lives = 6;
  int color[5];
  char* guess;
  char* word = getRandomWord();
  bool guessed = false;
  

  populateFrequencyMap(word);

  while (!guessed && (lives>0)) {
    guess = getGuess();

    for (int i = 0; i < 5; i++) {
      if (is_in_string(guess[i])) {
        color[i]++; //yellow
	if (is_in_position(guess[i])) {
	  color[i]++; //green
	}
      }
    }

    colorBoxes(color);

    for (int i = 0; i < 5; i++) {
      color[i] = 0;
    }
    lives--;
  }

  clearFrequencyMap();
}

int main() {
  // gamelogic();
}

