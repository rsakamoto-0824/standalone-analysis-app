"use strict";
const imageDialog = document.getElementById("image-dialog");
const dialogImage = document.getElementById("dialog-image");
const dialogCaption = document.getElementById("dialog-caption");
document.querySelectorAll(".image-open").forEach((button) => {
  button.addEventListener("click", () => {
    const sourceImage = button.querySelector("img");
    dialogImage.src = sourceImage.src;
    dialogImage.alt = sourceImage.alt;
    dialogCaption.textContent = sourceImage.alt;
    imageDialog.showModal();
  });
});
document.getElementById("dialog-close").addEventListener("click", () => imageDialog.close());
imageDialog.addEventListener("click", (event) => {
  if (event.target === imageDialog) imageDialog.close();
});
document.querySelectorAll(".reset-checks").forEach((button) => {
  button.addEventListener("click", () => {
    button.closest("section").querySelectorAll("input[type=checkbox]").forEach((checkbox) => { checkbox.checked = false; });
  });
});
