import random

secret = random.randint(1, 100)
guesses = 0

while True:
    guess = int(input("Guess a number between 1 and 100: "))
    guesses += 1
    if guess < secret:
        print("Too low")
    elif guess > secret:
        print("Too high")
    else:
        print(f"Correct! It took {guesses} tries")
        break
